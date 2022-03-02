# frozen_string_literal: true

class Admin::RdvCollectifWizardForm::Step4
  include Admin::RdvWizardFormConcern
  include Admin::RdvCollectifWizardFormConcern
  include Admin::RdvFormConcern

  def save
    result = valid? && rdv.save
    Notifiers::RdvCreated.perform_with(@rdv, @agent_author) if result
    result
  end

  def success_path
    admin_organisation_rdvs_collectifs_path(@rdv.organisation)
  end

  def success_flash
    { notice: "Le rendez-vous a été créé." }
  end
end
