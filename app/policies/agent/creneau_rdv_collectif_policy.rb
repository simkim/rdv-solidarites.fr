# frozen_string_literal: true

class Agent::CreneauRdvCollectifPolicy < Agent::AdminPolicy
  include CurrentAgentInPolicyConcern

  def agent_role_in_record_organisation
    @agent_role_in_record_organisation ||= \
      current_agent.roles.find_by(organisation_id: record.motif.organisation_id)
  end

  alias show? agent_role_in_record_organisation
  alias create? agent_role_in_record_organisation
  alias cancel? agent_role_in_record_organisation

  def new?
    true
  end

  alias update? agent_role_in_record_organisation
  alias edit? agent_role_in_record_organisation
  alias destroy? agent_role_in_record_organisation
  alias versions? agent_role_in_record_organisation

  class Scope < Scope
    include CurrentAgentInPolicyConcern

    def resolve
      scope.joins(motif: :organisation).where(motifs: { organisation: current_agent.organisations })
    end
  end
end
