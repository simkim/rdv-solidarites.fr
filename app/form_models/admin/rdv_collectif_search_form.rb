# frozen_string_literal: true

class Admin::RdvCollectifSearchForm
  include ActiveModel::Model

  attr_accessor :organisation_id, :motif_id, :with_availabilities

  def filter(rdvs)
    if motif_id.present?
      rdvs = rdvs.where(motif_id: motif_id)
    end

    if with_availabilities.to_bool
      rdvs = rdvs.where("rdv_collectif_users_count < max_participants_count OR max_participants_count IS NULL")
    end

    rdvs.where("starts_at >= ?", from_date)
  end

  def motif
    organisation.motifs.find_by(id: motif_id)
  end

  def from_date=(date)
    @from_date = date.is_a?(String) ? DateTime.parse(date) : date
  rescue Date::Error
    Time.zone.today
  end

  def from_date
    @from_date.presence || Time.zone.now
  end
end
