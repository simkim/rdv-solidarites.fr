# frozen_string_literal: true

class TeamPolicy < ApplicationPolicy
  include CurrentAgentInPolicyConcern

  def agent_territory_admin?
    current_agent.territorial_admin_in?(record.organisation.territory)
  end

  alias create? agent_territory_admin?
  alias update? agent_territory_admin?
  alias edit? agent_territory_admin?

  class Scope < Scope
    include CurrentAgentInPolicyConcern

    def resolve
      @scope.where(territory: @territory)
    end
  end
end
