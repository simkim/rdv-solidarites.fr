# frozen_string_literal: true

class Admin::Territories::BaseController < ApplicationController
  include Admin::AuthenticatedControllerConcern

  layout "application_configuration"

  # rubocop:disable Rails/LexicallyScopedActionFilter
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index
  # rubocop:enable Rails/LexicallyScopedActionFilter

  before_action :set_territory

  def current_territory
    @territory
  end
  helper_method :current_territory

  def pundit_user
    AgentContext.new(current_agent)
  end

  private

  def set_territory
    @territory = Territory.find(params[:territory_id])
  end
end
