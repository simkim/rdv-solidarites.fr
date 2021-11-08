# frozen_string_literal: true

# https://pad.incubateur.net/jftuVsrKTsKbn3ay8AoL0Q?edit
module SlotBuilder
  # À faire avant, au moment de jouer avec le motifs
  # @for_agents ? motifs : motifs.reservable_online

  def self.available_slots(motif, date_range, organisation, off_days, *options)
    # options :  { agents: [], lieux: [] }
    plage_ouvertures = plage_ouvertures_for(motif, date_range, organisation, options)
    free_times = free_times_from(plage_ouvertures, date_range, off_days) # dépendance sur RDV et Absence
    slots_for(free_times, motif)
  end

  def self.plage_ouvertures_for(motif, date_range, organisation, *_options)
    # TODO: filtre sur le lieu des options
    organisation.plage_ouvertures.for_motif_object(motif).not_expired.in_range(date_range)
  end

  def self.free_times_from(plage_ouvertures, date_range, off_days)
    free_times = {}
    plage_ouvertures.each do |plage_ouverture|
      free_times[plage_ouverture] = calculate_free_times(plage_ouverture, date_range, off_days)
    end
    free_times
    # TODO: retourner plutôt un enumérator histoire d'être lazy ?
  end

  def self.calculate_free_times(plage_ouverture, date_range, _off_days)
    ranges = [range_for(plage_ouverture, date_range)].compact
    return if ranges.empty?

    # On soustrait les RDV du temps disponible
    rdvs = plage_ouverture.agent.rdvs.where(starts_at: date_range).or(plage_ouverture.agent.rdvs.where(ends_at: date_range))

    ranges = split_range_with_loop(ranges, rdvs)
    # TODO: manque les absences / indisponibilités
    ranges.select { |r| ((r.end.to_i - r.begin.to_i) / 60).positive? }
  end

  def self.range_for(plage_ouverture, date_range)
    occurrences = plage_ouverture.occurrences_for(date_range)
    return [] if occurrences.empty?

    # TODO: prendre en considération qu'il peut y avoir plusieurs occurrence
    occurrences.first.starts_at..occurrences.first.ends_at
  end

  def self.split_range_with_loop(ranges, rdvs)

    # décalle le début du range
    # TODO Et s'il y a plusieurs RDV en même temps qui couvre le début de la plage ?
    rdv_overlapping_range_begin = rdvs.select { |rdv| (rdv.starts_at..rdv.ends_at).cover?(ranges.first.begin) }.first
    if rdv_overlapping_range_begin
      ranges = [(rdv_overlapping_range_begin.ends_at..ranges.first.end)]
      rdvs -= [rdv_overlapping_range_begin]
    end

    # décalle la fin du range
    # TODO Et s'il y a plusieurs RDV en même temps qui couvre la fin de la plage ?
    rdv_overlapping_range_end = rdvs.select { |rdv| (rdv.starts_at..rdv.ends_at).cover?(ranges.first.end) }.first
    if rdv_overlapping_range_end
      ranges = [(ranges.first..rdv_overlapping_range_end.starts_at)]
      rdvs -= [rdv_overlapping_range_end]
    end

    # supprime les rdv inclus
    rdvs.each do |rdv|
      range_to_split = ranges.last
      new_range = range_to_split.begin..rdv.starts_at
      new_last_range = rdv.ends_at..range_to_split.end
      ranges = ranges[..-2] + [new_range, new_last_range]
    end

    ranges
  end

  def self.slots_for(plage_ouverture_free_times, motif)
    slots = []
    plage_ouverture_free_times.each do |plage_ouverture, free_times|
      free_times.each do |free_time|
        slots += calculate_slots(free_time, motif) do |starts_at|
          Creneau.new(
            starts_at: starts_at,
            motif: motif,
            lieu_id: plage_ouverture.lieu,
            agent_id: plage_ouverture.agent_id,
            agent_name: plage_ouverture.agent.full_name
          )
        end
      end
    end
    slots
  end

  def self.calculate_slots(free_time, motif, &build_creneau)
    return [] unless block_given?

    slots = []
    possible_slot_time = free_time.begin..(free_time.begin + motif.default_duration_in_min.minutes)
    while possible_slot_time.end <= free_time.end
      slots << build_creneau.call(possible_slot_time.begin)
      possible_slot_time = possible_slot_time.end..(possible_slot_time.end + motif.default_duration_in_min.minutes)
    end
    slots
  end
end
