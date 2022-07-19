# frozen_string_literal: true

module RdvUpdater
  class << self
    def update(author, rdv, rdv_params)
      # Explicitly touch the Rdv to make sure a new Version is saved on paper_trail
      # This may be needed when changing associations, when adding/removing an agent or a user.
      rdv.updated_at = Time.zone.now

      # Set/reset cancelled_at when the status changes
      if rdv_params[:status].present?
        rdv_params[:cancelled_at] = rdv_params[:status].in?(%w[excused revoked noshow]) ? Time.zone.now : nil
      end

      previous_participant_ids = rdv.participants_with_life_cycle_notification_ids

      success = rdv.update(rdv_params)

      Result.new(
        success: success,
        rdv_users_tokens_by_user_id: success ? notify!(author, rdv, previous_participant_ids) : {}
      )
    end

    def rdv_status_reloaded_from_cancelled?(rdv)
      rdv.status_previously_was.in?(%w[revoked excused]) &&
        rdv.status == "unknown"
    end

    def notify!(author, rdv, previous_participant_ids)
      rdv_users_tokens_by_user_id = {}
      if rdv_cancelled?(rdv)
        rdv.file_attentes.destroy_all
        rdv_users_tokens_by_user_id = Notifiers::RdvCancelled.perform_with(rdv, author)
      end

      if rdv_status_reloaded_from_cancelled?(rdv)
        rdv_users_tokens_by_user_id = Notifiers::RdvCreated.perform_with(rdv, author)
      end

      if starts_at_change?(rdv)
        rdv_users_tokens_by_user_id = Notifiers::RdvDateUpdated.perform_with(rdv, author)
      end

      if rdv.collectif?
        rdv_users_tokens_by_user_id = Notifiers::RdvCollectifParticipations.perform_with(rdv, author, previous_participant_ids)
      end

      if lieu_change?(rdv)
        rdv_users_tokens_by_user_id = Notifiers::RdvLieuUpdated.perform_with(rdv, author)
      end

      rdv_users_tokens_by_user_id
    end

    def lieu_change?(rdv)
      rdv.previous_changes["lieu_id"].present?
    end

    private

    def rdv_cancelled?(rdv)
      rdv.previous_changes["status"]&.last.in? %w[excused revoked noshow]
    end

    def starts_at_change?(rdv)
      rdv.previous_changes["starts_at"].present?
    end
  end

  class Result
    attr_reader :success, :rdv_users_tokens_by_user_id
    alias success? success

    def initialize(success:, rdv_users_tokens_by_user_id: {})
      @success = success
      @rdv_users_tokens_by_user_id = rdv_users_tokens_by_user_id
    end
  end
end
