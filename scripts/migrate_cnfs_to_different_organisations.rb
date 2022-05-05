# frozen_string_literal: true

# rails runner scripts/migrate_cnfs_to_different_organisations.rb
# rubocop:disable Rails/SkipsModelValidations

old_organisation = Organisation.find(609)

agent_emails_by_structure = [
  # These are arrays of emails of agents that are in the same organisation, for example:
  # ["collegue1@conseiller-numerique.fr", "collegue2@conseiller-numerique.fr"],
]

class MotifsPlageOuverture < ApplicationRecord
end

ActiveRecord::Base.transaction do
  agent_emails_by_structure.each do |agent_emails|
    puts "Migration for #{agent_emails}"
    agent_ids = Agent.where(email: agent_emails).pluck(:id)
    new_organisation = Organisation.create!(
      territory_id: 31,
      name: "La Poste"
    )
    agent_ids.each do |agent_id|
      AgentRole.create!(agent_id: agent_id, organisation_id: new_organisation.id, level: :admin)
    end

    # migrer les plages d'ouverture
    plage_ouvertures_for_organisation = PlageOuverture.where(agent_id: agent_ids)
    plage_ouvertures_for_organisation.where(organisation: old_organisation).update_all(organisation_id: new_organisation.id)

    # creer des duplicatas de motifs, et y associer les plages d'ouvertures, et les rdvs
    Motif.joins(rdvs: :agents_rdvs).where(agents_rdvs: { agent_id: agent_ids }).find_each do |old_motif|
      new_motif = old_motif.dup
      new_motif.organisation = new_organisation
      new_motif.save

      MotifsPlageOuverture.where(motif_id: old_motif, plage_ouverture_id: plage_ouvertures_for_organisation).update_all(motif_id: new_motif.id)

      Rdv.joins(:agents_rdvs).where(agents_rdvs: { agent_id: agent_ids }, motif: old_motif).update_all(motif_id: new_motif.id)
    end

    # migrer les rdv dans les nouveaux
    Rdv.joins(:agents_rdvs).where(agents_rdvs: { agent_id: agent_ids }).update_all(organisation_id: new_organisation.id)

    # migrer les lieux (en espérant qu'il n'y ai pas de lieux utilisés par plusieurs organisations différentes)
    Lieu.joins(rdvs: :agents_rdvs).where(agents_rdvs: { agent_id: agent_ids }).where(organisation: old_organisation).update_all(organisation_id: new_organisation.id)

    # migrer les absence
    Absence.where(agent_id: agent_ids).where(organisation: old_organisation).update_all(organisation_id: new_organisation.id)

    # et ajouter les usagers
    User.joins(rdvs_users: { rdv: :agents_rdvs }).where(agents_rdvs: { agent_id: agent_ids }).find_each do |user|
      user.add_organisation(new_organisation)
    end

    agent_ids.each do |agent_id|
      AgentRole.find_by(organisation_id: old_organisation.id, agent_id: agent_id).delete
    end
    puts "done !"
  end
end

# rubocop:enable Rails/SkipsModelValidations
