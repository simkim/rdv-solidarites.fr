# frozen_string_literal: true

class Admin::Territories::TeamsController < Admin::Territories::BaseController
  def index
    @teams = current_territory.teams.page(params[:page])
    @teams = params[:search].present? ? @teams.search_by_text(params[:search]) : @teams.order(:name)
  end

  def new
    @team = Team.new
  end

  def create
    @team = Team.new(territory: current_territory)
    authorize_admin(@team)
    if @team.update(team_params.merge)
      redirect_to admin_territory_teams_path(current_territory)
    else
      render :new
    end
  end

  def edit
    @team = Team.find(params[:id])
    authorize_admin(@team)
  end

  def update
    @team = Team.find(params[:id])
    authorize_admin(@team)
    if @team.update(team_params)
      redirect_to admin_territory_teams_path(current_territory)
    else
      render :new
    end
  end

  def destroy
    team = Team.find(params[:id])
    authorize_admin(team)
    team.destroy!
    redirect_to admin_territory_teams_path(current_territory)
  end

  def search
    teams = TeamPolicy::Scope.new(current_territory, Team).resolve.limit(10)
    @teams = search_params[:term].present? ? teams.search_by_text(search_params[:term]) : teams.order(:name)
  end

  private

  def search_params
    @search_params ||= params.permit(:term)
  end

  def team_params
    params.require(:team).permit(:name, agent_ids: [])
  end
end
