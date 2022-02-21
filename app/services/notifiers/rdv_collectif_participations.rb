# frozen_string_literal: true

class Notifiers::RdvCollectifParticipations < ::BaseService
  def initialize(rdv, previous_participant_ids)
    @rdv = rdv
    @previous_participant_ids = previous_participant_ids
  end

  def perform
    return if @rdv.starts_at < Time.zone.now

    notify_users_by_mail
    notify_users_by_sms
  end

  private

  def notify_users_by_mail
    new_participants.select(&:notifiable_by_email?).each do |user|
      Users::RdvMailer.rdv_created(@rdv.payload(:create, user), user).deliver_later
      @rdv.events.create!(event_type: RdvEvent::TYPE_NOTIFICATION_MAIL, event_name: :created)
    end

    deleted_participants.select(&:notifiable_by_email?).each do |user|
      Users::RdvMailer.rdv_cancelled(@rdv.payload(:destroy, user), user).deliver_later
      @rdv.events.create!(event_type: RdvEvent::TYPE_NOTIFICATION_MAIL, event_name: :cancelled_by_agent)
    end
  end

  def notify_users_by_sms
    new_participants.select(&:notifiable_by_sms?).each do |user|
      Users::RdvSms.rdv_created(@rdv, user).deliver_later
      @rdv.events.create!(event_type: RdvEvent::TYPE_NOTIFICATION_SMS, event_name: :created)
    end

    deleted_participants.select(&:notifiable_by_sms?).each do |user|
      Users::RdvSms.rdv_cancelled(@rdv, user).deliver_later
      @rdv.events.create!(event_type: RdvEvent::TYPE_NOTIFICATION_SMS, event_name: :cancelled_by_agent)
    end
  end

  def new_participants
    @new_participants ||= User.where(id: (@rdv.user_ids - @previous_participant_ids))
  end

  def deleted_participants
    @deleted_participants ||= User.where(id: (@previous_participant_ids - current_participant_ids))
  end

  def current_participant_ids
    @rdv.rdvs_users.where(send_lifecycle_notifications: true).pluck(:user_id)
  end
end
