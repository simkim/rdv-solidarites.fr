# frozen_string_literal: true

class Admins::OrganisationMailer < ApplicationMailer
  def organisation_created(agent, organisation)
    @agent = agent
    @organisation = organisation
    mail(to: "support@rdv-solidarites.fr", subject: "Nouvelle organisation créée - #{@organisation.departement_number} - #{@organisation.name}")
  end
end
