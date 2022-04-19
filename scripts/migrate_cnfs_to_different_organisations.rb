# frozen_string_literal: true

# rails runner scripts/migrate_cnfs_to_different_organisations.rb
# rubocop:disable Rails/SkipsModelValidations

class MotifsPlageOuverture < ApplicationRecord
end

class MigrateToNewOrganisation
  def self.run(new_organisation:, old_organisation:, agent:)
    agent_ids = [agent.id]

    ActiveRecord::Base.transaction do
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

      # migrer les rdv dans les nouvelles organisations
      Rdv.joins(:agents_rdvs).where(agents_rdvs: { agent_id: agent_ids }).update_all(organisation_id: new_organisation.id)

      # migrer les lieux (en espérant qu'il n'y ai pas de lieux utilisés par plusieurs organisations différentes)
      Lieu.joins(rdvs: :agents_rdvs).where(agents_rdvs: { agent_id: agent_ids }).where(organisation: old_organisation).update_all(organisation_id: new_organisation.id)

      # migrer les absence
      Absence.where(agent_id: agent_ids).where(organisation: old_organisation).update_all(organisation_id: new_organisation.id)

      # et ajouter les usagers
      User.joins(rdvs_users: { rdv: :agents_rdvs }).where(agents_rdvs: { agent_id: agent_ids }).find_each do |user|
        user.add_organisation(new_organisation)
      end
    end
  end
end
# rubocop:enable Rails/SkipsModelValidations
#
# List of organisations with at least 5 members
# AgentRole.joins(organisation: :territory).where(territories: { id: 31 }).group(:organisation_id).having("count(*) > 5").order("organisation_id desc").count

require "csv"
conseillers_numeriques = CSV.read("/tmp/uploads/export-cnfs-full.csv", headers: true, col_sep: ";")

cnfs_emails_by_structure_ids = Hash.new([])

conseillers_numeriques.each do |conseiller_numerique|
  cnfs_emails_by_structure_ids[conseiller_numerique["Id de la structure"]] += [conseiller_numerique["Email @conseiller-numerique.fr"]]
end

# Faire un hash email_structure => [emails cnfs]

# Parcourir tous les cnfs existants
# Tous les cnfs sont dans une seule organisation
# Trouver tous les cnfs qui sont dans des organisations groupées à tord
# Trouver les cnfs sans rdv qui sont dans la mauvaise orga, et les mettre dans une nouvelle orga
#
false_colleagues_hash = {}

Agent.joins(:organisations).where(organisations: { territory_id: 31 }).where("agents.email ilike '%conseiller-numerique.fr'").distinct.find_each do |agent|
  organisation = agent.organisations&.first

  next unless organisation

  structure_id = cnfs_emails_by_structure_ids.find do |_structure_id, cnfs_emails|
    agent.email.in?(cnfs_emails)
  end&.first
  next unless structure_id

  colleague_emails = cnfs_emails_by_structure_ids[structure_id] - [agent.email]

  false_colleagues = organisation.agents.joins(:roles).where(roles: { level: :admin }).pluck(:email) - colleague_emails - [agent.email]

  next if false_colleagues.empty?

  false_colleagues_hash[agent.email] = false_colleagues
  false_colleague_email = false_colleagues.first

  false_colleague_agent = Agent.find_by(email: false_colleague_email)

  cnfs_false_colleague = conseillers_numeriques.find do |conseiller_numerique|
    conseiller_numerique["Email @conseiller-numerique.fr"] == false_colleague_email
  end

  new_organisation = Organisation.create!(
    territory_id: 31,
    email: cnfs_false_colleague["Email de la structure"],
    name: cnfs_false_colleague["Nom de la structure"]
  )

  AgentRole.create!(organisation_id: new_organisation.id, agent_id: false_colleague_agent.id, level: :admin)

  MigrateToNewOrganisation.run(
    agent: false_colleague_agent,
    new_organisation: new_organisation,
    old_organisation: organisation
  )
end

puts "done"
