# frozen_string_literal: true

class Admin::CreneauRdvCollectifsController < AgentAuthController
  def index
    @creneau_rdv_collectifs = policy_scope(CreneauRdvCollectif).where(motifs: { organisation: current_organisation }).page(filter_params[:page])
  end

  def new
    @creneau_rdv_collectif = CreneauRdvCollectif.new
    authorize(@creneau_rdv_collectif)
  end

  def edit
  end

  def create
  end

  def update
    authorize(@absence)
    if @absence.update(absence_params)
      Agents::AbsenceMailer.absence_updated(@absence.payload(:update)).deliver_later
      flash[:notice] = t(".busy_time_updated")
      redirect_to admin_organisation_agent_absences_path(@absence.organisation_id, @absence.agent_id)
    else
      render :edit
    end
  end

  private

  def filter_params
    params.permit(:page, :current_tab)
  end
end
