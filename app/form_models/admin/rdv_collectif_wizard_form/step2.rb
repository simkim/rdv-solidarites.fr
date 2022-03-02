# frozen_string_literal: true

class Admin::RdvCollectifWizardForm::Step2
  include Admin::RdvWizardFormConcern
  include Admin::RdvCollectifWizardFormConcern
  include Admin::RdvFormConcern

  def success_path
    new_admin_organisation_rdv_collectif_wizard_step_path(@organisation, step: 4, **to_query)
  end

  protected

  def agent_context
    AgentContext.new(@agent_author, @organisation)
  end
end
