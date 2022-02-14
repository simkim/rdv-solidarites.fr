# frozen_string_literal: true

class CreneauRdvCollectif < ApplicationRecord
  include RecurrenceConcern

  belongs_to :lieu
  belongs_to :motif

  has_many :rdv_collectifs, dependent: :destroy

  has_many :creneau_rdv_collectifs_agents, dependent: :destroy
  has_many :agents, through: :creneau_rdv_collectifs_agents

  def end_time
    return if motif.blank?

    start_time + (motif.default_duration_in_min * 60)
  end
end
