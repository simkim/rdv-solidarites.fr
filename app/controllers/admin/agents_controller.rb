# frozen_string_literal: true

class Admin::AgentsController < AgentAuthController
  respond_to :html, :json

  def index
    @agents = policy_scope(Agent)
      .joins(:organisations).where(organisations: { id: current_organisation.id })
      .includes(:service, :roles, :organisations)
      .active
    @invited_agents_count = @agents.invitation_not_accepted.created_by_invite.count
    @agents = index_params[:term].present? ? @agents.search_by_text(index_params[:term]) : @agents.order_by_last_name
    @agents = @agents.complete.page(params[:page])
  end

  def destroy
    @agent = policy_scope(Agent).find(params[:id])
    authorize(@agent)
    removal_service = AgentRemoval.new(@agent, current_organisation)
    if removal_service.upcoming_rdvs?
      redirect_to edit_admin_organisation_agent_role_path(current_organisation, @agent.role_in_organisation(current_organisation)), flash: { error: t(".cannot_delete_because_of_rdvs") }
    else
      removal_service.remove!
      if @agent.invitation_accepted_at.blank?
        redirect_to admin_organisation_invitations_path(current_organisation), notice: t(".invitation_deleted")
      elsif @agent.deleted_at?
        redirect_to admin_organisation_agents_path(current_organisation), notice: t(".agent_deleted")
      else
        redirect_to admin_organisation_agents_path(current_organisation), notice: t(".agent_removed_from_org")
      end
    end
  end

  private

  def index_params
    @index_params ||= params.permit(:term)
  end
end
