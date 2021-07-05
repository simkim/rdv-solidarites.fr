# frozen_string_literal: true

# rails runner scripts/compute_organisation_stats.rb organisation_id

org = Organisation.find(ARGV[0])
users = org.users
targeted_users_count = users.where("created_at > ?", 30.days.ago).count

avec_email = { targeted: 0, oriented: 0, sans_rdv: 0, validation_compte: [], prise_de_rdv: [], delai_rdv: [], delai_rdv_total: [], delai_rdv_effectif: [] }
sans_email = { targeted: 0, oriented: 0, sans_rdv: 0, validation_compte: [], prise_de_rdv: [], delai_rdv: [], delai_rdv_total: [], delai_rdv_effectif: [] }

users.each do |user|
  hash = if user.versions.first.changeset[:email]
           avec_email
         else
           sans_email
         end
  hash[:targeted] += 1 if user.created_at > 30.days.ago
  hash[:oriented] += 1 if user.created_at > 30.days.ago && user.rdvs.where(status: 2).first
  if user.invitation_accepted_at
    hash[:sans_rdv] += 1 if user.rdvs.empty?
    hash[:validation_compte] << user.invitation_accepted_at - user.created_at
  end
  if (rdv = user.rdvs.first)
    hash[:prise_de_rdv] << rdv.created_at - user.invitation_accepted_at
    hash[:delai_rdv] << rdv.starts_at - rdv.created_at
    hash[:delai_rdv_total] << rdv.starts_at - user.created_at
  end
  if (rdv_effectue = user.rdvs.where(status: 2).first)
    hash[:delai_rdv_effectif] << rdv_effectue.starts_at - user.created_at
  end
end

def display_stats(stat_name, stat_text, avec_email, sans_email)
  source_avec = avec_email[:"#{stat_name}"]
  source_sans = sans_email[:"#{stat_name}"]
  avec_email[:"#{stat_name}_average"] = source_avec.sum / source_avec.size if source_avec.size.positive?
  sans_email[:"#{stat_name}_average"] = source_sans.sum / source_sans.size if source_sans.size.positive?
  stat_average = (source_avec + source_sans).sum / (source_avec + source_sans).size if source_avec.size.positive? || source_sans.size.positive?

  puts "Délai moyen #{stat_text} : #{stat_average.fdiv(86_400).round(2)} jours" if stat_average
  puts "compte avec email : #{avec_email[:"#{stat_name}_average"].fdiv(86_400).round(2)} jours" if avec_email[:"#{stat_name}_average"]
  puts "compte sans email : #{sans_email[:"#{stat_name}_average"].fdiv(86_400).round(2)} jours" if sans_email[:"#{stat_name}_average"]
  puts
end

puts "Cacul des statistiques pour l'organisation #{org.name} (#{org.departement})"
puts

puts "#{users.count} usagers pour cette organisation"
puts "dont #{users.where.not(invitation_accepted_at: nil).count} usagers ayant validé leurs comptes"
puts "dont #{avec_email[:sans_rdv] + sans_email[:sans_rdv]} usagers actifs sans rendez-vous"
puts "#{sans_email[:validation_compte].size} usagers n'avaient pas de mail à la création du compte"
puts

puts "#{avec_email[:oriented] + sans_email[:oriented]} usagers sur #{targeted_users_count} orientés en moins de 30 jours"
puts "soit #{(avec_email[:oriented] + sans_email[:oriented] / targeted_users_count) * 100}% d'usagers orientés en moins de 30 jours" if targeted_users_count.positive?
puts "#{avec_email[:oriented]} usagers avec email sur #{avec_email[:targeted]} orientés en moins de 30 jours"
puts "soit #{(avec_email[:oriented] / avec_email[:targeted]) * 100}% d'usagers avec email orientés en moins de 30 jours" if avec_email[:targeted].positive?
puts "#{sans_email[:oriented]} usagers sans email sur #{sans_email[:targeted]} orientés en moins de 30 jours"
puts "soit #{(sans_email[:oriented] / sans_email[:targeted]) * 100}% d'usagers sans email orientés en moins de 30 jours" if sans_email[:targeted].positive?
puts

puts "#{org.rdvs.count} rdvs pris pour cette organisation"
puts "#{org.rdvs.future.not_cancelled.count} rdvs en attente pour cette organisation"
puts "#{org.rdvs.seen.count} rdvs effectués pour cette organisation"
puts "#{org.rdvs.excused.count} rdvs annulés pour cette organisation"
puts "#{org.rdvs.notexcused.count} lapins"
puts

display_stats("validation_compte", "d'activation d'un compte", avec_email, sans_email)
display_stats("prise_de_rdv", "pour prendre un rdv", avec_email, sans_email)
display_stats("delai_rdv", "pour avoir un rdv", avec_email, sans_email)
display_stats("delai_rdv_total", "entre la création du compte et le 1er rdv", avec_email, sans_email)
display_stats("delai_rdv_effectif", "entre la création du compte et le 1er rdv effectué", avec_email, sans_email)