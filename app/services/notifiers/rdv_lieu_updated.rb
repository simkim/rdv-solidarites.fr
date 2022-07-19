# frozen_string_literal: true

class Notifiers::RdvLieuUpdated < Notifiers::RdvBase
  protected

  def rdvs_users_to_notify
    @rdv.rdvs_users.where(send_lifecycle_notifications: true)
  end

  def notify_user_by_mail(user)
    user_mailer(user).rdv_lieu_updated(@rdv.attribute_before_last_save(:lieu_id)).deliver_later
  end
end
