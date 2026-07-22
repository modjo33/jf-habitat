# Recale le barème interne (rendement m²/h, coût matière €/m²) sur ce que les
# chantiers ont réellement coûté.
#
# Principe : à chaque devis où Johan a saisi ses HEURES RÉELLES, on obtient un
# rapport réel/prévu. Idem pour la matière dès qu'il a saisi des DÉPENSES.
# Un rapport de 2 veut dire « je mets deux fois plus de temps que le barème ne
# le dit » → le rendement doit être divisé par deux.
#
# Attribution par poste : un chantier mélange souvent plusieurs prestations et
# les heures sont saisies globalement. On répartit donc le rapport observé sur
# chaque poste du chantier, PONDÉRÉ par sa part des heures prévues. Un poste
# qui pesait 80 % du temps prévu porte 80 % de la responsabilité de l'écart.
#
# Rien n'est appliqué automatiquement : le service PROPOSE, Johan valide.
class CalibrageBareme
  # En dessous, l'échantillon est trop maigre pour toucher au barème.
  MIN_OBSERVATIONS = 1
  # Garde-fou : on refuse de proposer un rendement absurde à partir d'un seul
  # chantier atypique.
  RATIO_MIN = 0.2
  RATIO_MAX = 5.0

  Proposition = Struct.new(
    :cle, :objet, :libelle,
    :rendement_actuel, :rendement_propose,
    :matiere_actuelle, :matiere_proposee,
    :observations, :ratio_heures, :ratio_matiere,
    keyword_init: true
  )

  def initialize(analyses = nil)
    @analyses = analyses || DevisAnalyse.includes(estimation: [:depenses, :devis_lignes, { pieces: :murs }]).to_a
  end

  # --- Observations ---------------------------------------------------------

  # Devis où les heures réelles ont été saisies ET où le barème prévoyait
  # quelque chose : sans les deux, aucun rapport calculable.
  def analyses_avec_heures
    @analyses.select { |a| a.heures_saisies.present? && a.heures_auto.to_d.positive? }
  end

  def analyses_avec_matiere
    @analyses.select { |a| a.depenses_reelles? && a.cout_materiaux_auto.to_d.positive? }
  end

  def ratio_heures_global
    mediane(analyses_avec_heures.map { |a| (a.heures_saisies.to_d / a.heures_auto.to_d) })
  end

  def ratio_matiere_global
    mediane(analyses_avec_matiere.map { |a| (a.cout_materiaux_reel / a.cout_materiaux_auto.to_d) })
  end

  def nb_observations_heures  = analyses_avec_heures.size
  def nb_observations_matiere = analyses_avec_matiere.size

  # --- Propositions par poste du barème -------------------------------------

  def propositions
    @propositions ||= begin
      heures  = observations_par_cle(analyses_avec_heures)  { |a| a.heures_saisies.to_d / a.heures_auto.to_d }
      matiere = observations_par_cle(analyses_avec_matiere) { |a| a.cout_materiaux_reel / a.cout_materiaux_auto.to_d }

      (heures.keys | matiere.keys).filter_map do |cle|
        objet = resoudre(cle)
        next if objet.nil?

        rh = moyenne_ponderee(heures[cle])
        rm = moyenne_ponderee(matiere[cle])
        next if rh.nil? && rm.nil?

        Proposition.new(
          cle: cle, objet: objet, libelle: libelle_pour(objet),
          rendement_actuel:  objet.rendement_m2_h,
          # Aller 2× moins vite = rendement 2× plus petit.
          rendement_propose: (rh && objet.rendement_m2_h.to_d.positive? ? (objet.rendement_m2_h.to_d / rh).round(2) : nil),
          matiere_actuelle:  objet.cout_matiere_unite,
          matiere_proposee:  (rm && objet.cout_matiere_unite.to_d.positive? ? (objet.cout_matiere_unite.to_d * rm).round(2) : nil),
          observations: [(heures[cle] || []).size, (matiere[cle] || []).size].max,
          ratio_heures: rh&.round(2), ratio_matiere: rm&.round(2)
        )
      end.sort_by { |p| -p.observations }
    end
  end

  def propositions_applicables
    propositions.select do |p|
      p.observations >= MIN_OBSERVATIONS &&
        (p.rendement_propose.present? || p.matiere_proposee.present?)
    end
  end

  # Applique les propositions retenues. `cles` limite aux postes cochés.
  def appliquer!(cles = nil)
    retenues = propositions_applicables
    retenues = retenues.select { |p| cles.include?(p.cle) } if cles.present?
    retenues.each do |p|
      attrs = {}
      attrs[:rendement_m2_h]     = p.rendement_propose if p.rendement_propose
      attrs[:cout_matiere_unite] = p.matiere_proposee  if p.matiere_proposee
      p.objet.update_columns(attrs) if attrs.any?
    end
    retenues.size
  end

  private

  # { cle => [[ratio, poids], …] } — poids = part des heures prévues du poste
  # dans le chantier, pour ne pas faire porter l'écart à un poste marginal.
  def observations_par_cle(analyses)
    acc = Hash.new { |h, k| h[k] = [] }
    analyses.each do |a|
      lignes = a.lignes_barème.select { |l| l[:cle].present? && l[:heures].to_d.positive? }
      total = lignes.sum { |l| l[:heures].to_d }
      next unless total.positive?
      ratio = yield(a)
      next unless ratio.finite? && ratio.between?(RATIO_MIN, RATIO_MAX)
      lignes.each { |l| acc[l[:cle]] << [ratio, (l[:heures].to_d / total)] }
    end
    acc
  end

  def moyenne_ponderee(paires)
    return nil if paires.blank?
    poids = paires.sum { |(_, p)| p }
    return nil unless poids.positive?
    (paires.sum { |(r, p)| r * p } / poids)
  end

  def mediane(valeurs)
    v = valeurs.compact.select { |x| x.finite? && x.between?(RATIO_MIN, RATIO_MAX) }.sort
    return nil if v.empty?
    milieu = v.size / 2
    v.size.odd? ? v[milieu] : ((v[milieu - 1] + v[milieu]) / 2)
  end

  def resoudre(cle)
    type, id = cle.split(":")
    type == "tarif" ? Tarif.find_by(id: id) : Prestation.find_by(id: id)
  end

  def libelle_pour(objet)
    if objet.is_a?(Tarif)
      "#{Tarif::PRESTATIONS.dig(objet.prestation, :label) || objet.prestation} · #{Tarif::GAMMES.dig(objet.gamme, :label) || objet.gamme}"
    else
      objet.nom
    end
  end
end
