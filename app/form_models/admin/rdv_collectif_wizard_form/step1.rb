# frozen_string_literal: true

class Admin::RdvCollectifWizardForm::Step1
  include Admin::RdvWizardFormConcern
  include Admin::RdvCollectifWizardFormConcern
  validates :motif, :organisation, presence: true

  def success_path
    new_admin_organisation_rdv_collectif_wizard_step_path(@organisation, step: 2, **to_query)
  end
end
