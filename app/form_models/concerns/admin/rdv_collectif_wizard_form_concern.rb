# frozen_string_literal: true

module Admin::RdvCollectifWizardFormConcern
  def previous_step_path
    if step_number <= 1
      admin_organisation_rdvs_collectifs_path(organisation)
    else
      path_for_step(step_number - 1)
    end
  end

  def path_for_step(target_step_number)
    new_admin_organisation_rdv_collectif_wizard_step_path(organisation, to_query.merge(step: target_step_number))
  end
end
