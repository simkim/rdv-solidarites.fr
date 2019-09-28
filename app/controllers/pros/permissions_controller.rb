class Pros::PermissionsController < DashboardAuthController
  respond_to :html, :json

  def edit
    @permission = Pro::Permission.new(pro: Pro.find(params[:id]))
    authorize(@permission)
    respond_right_bar_with @permission
  end

  def update
    @permission = Pro::Permission.new(pro: Pro.find(params[:id]))
    authorize(@permission)
    @permission.update(permission_params)
    respond_right_bar_with @permission, location: pros_path
  end

  private

  def permission_params
    params.require(:pro_permission).permit(:role, :service_id)
  end
end
