class RdvCollectif
  AUTHORIZED_ORGANISATION_IDS = ENV["RDVC_ORGANISATION_IDS"]&.split(",")&.map(&:to_i) || []

  def self.enabled_for?(organisation)
    organisation.id.in?(AUTHORIZED_ORGANISATION_IDS)
  end
end
