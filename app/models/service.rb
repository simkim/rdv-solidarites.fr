# frozen_string_literal: true

class Service < ApplicationRecord
  # Attributes
  auto_strip_attributes :name, :short_name

  SECRETARIAT = "Secrétariat"
  SERVICE_SOCIAL = "Service social"
  PMI = "PMI (Protection Maternelle Infantile)"

  # Relations
  has_many :agents, dependent: :nullify
  has_many :motifs, dependent: :destroy

  # Validations
  validates :name, :short_name, presence: true, uniqueness: { case_sensitive: false }

  # Scopes
  scope :with_motifs, -> { where.not(name: SECRETARIAT) }
  scope :secretariat, -> { where(name: SECRETARIAT) }
  scope :ordered_by_name, -> { order(Arel.sql("unaccent(LOWER(name))")) }

  ## -

  def self.all_for_territory(territory)
    where(agents: Agent.joins(:organisations).merge(territory.organisations))
  end

  def secretariat?
    name == SECRETARIAT
  end

  def service_social?
    name == SERVICE_SOCIAL
  end

  def pmi?
    name == PMI
  end

  def user_field_groups
    related_to_social? ? [:social] : []
  end

  def related_to_social?
    service_social? || name.parameterize.include?("social")
  end
end
