# Calcul pur de la rentabilité d'un devis — aucune écriture, aucun accès base
# au-delà de l'analyse reçue. Testable au centime, comme CalculDeclarations.
#
# Règle de fond : en micro-entreprise, les cotisations se calculent sur le
# CHIFFRE D'AFFAIRES, pas sur le bénéfice. On ne peut donc pas additionner les
# coûts pour obtenir un prix : il faut résoudre à l'envers (voir prix_plancher).
class AnalyseRentabilite
  # Micro-BIC prestations de services : l'abattement forfaitaire de 50 %
  # remplace les frais réels. L'impôt ne porte que sur la moitié du CA.
  ABATTEMENT_MICRO_BIC = 0.5.to_d

  Resultat = Struct.new(
    :montant_devis, :cout_materiaux, :cout_materiaux_estime, :cout_materiaux_reel,
    :ecart_materiaux, :ecart_materiaux_pct, :depenses_reelles,
    :autres_frais, :cout_total,
    :heures, :heures_par_jour, :jours,
    :taux_cotisations_global, :taux_impot, :taux_prelevement,
    :cotisations, :provision_impot,
    :benefice_brut, :benefice_net,
    :revenu_horaire, :revenu_journalier,
    :marge_euros, :marge_pct, :part_materiaux_pct,
    :objectif_horaire, :prix_plancher, :prix_conseille,
    :ecart_plancher, :alertes,
    keyword_init: true
  )

  def initialize(analyse)
    @a = analyse
    @estimation = analyse.estimation
  end

  def resultats
    Resultat.new(
      montant_devis: montant_devis, cout_materiaux: cout_materiaux,
      cout_materiaux_estime: @a.cout_materiaux_auto,
      cout_materiaux_reel: (@a.cout_materiaux_reel if @a.depenses_reelles?),
      ecart_materiaux: @a.ecart_materiaux, ecart_materiaux_pct: @a.ecart_materiaux_pct,
      depenses_reelles: @a.depenses_reelles?,
      autres_frais: autres_frais, cout_total: cout_total,
      heures: heures, heures_par_jour: heures_par_jour, jours: jours,
      taux_cotisations_global: taux_cotisations_global, taux_impot: taux_impot,
      taux_prelevement: (taux_prelevement * 100).round(2),
      cotisations: cotisations, provision_impot: provision_impot,
      benefice_brut: benefice_brut, benefice_net: benefice_net,
      revenu_horaire: revenu_horaire, revenu_journalier: revenu_journalier,
      marge_euros: benefice_net, marge_pct: marge_pct,
      part_materiaux_pct: part_materiaux_pct,
      objectif_horaire: objectif_horaire, prix_plancher: prix_plancher,
      prix_conseille: prix_conseille, ecart_plancher: (montant_devis - prix_plancher).round(2),
      alertes: alertes
    )
  end

  # --- Entrées ---------------------------------------------------------------

  def montant_devis   = @estimation.devis_total.to_d
  def cout_materiaux  = @a.cout_materiaux.round(2)
  def autres_frais    = @a.autres_frais.to_d.round(2)
  def cout_total      = (cout_materiaux + autres_frais).round(2)
  def heures          = @a.heures.round(2)
  def heures_par_jour = @a.heures_par_jour.to_d
  def objectif_horaire = @a.objectif_horaire.to_d

  def jours
    return 0.to_d unless heures_par_jour.positive?
    (heures / heures_par_jour).round(2)
  end

  # --- Taux (figés à la création de l'analyse) -------------------------------

  def taux_cotisations_global = @a.taux_global_fige
  def taux_impot              = @a.taux_impot.to_d

  # Part du CA réellement prélevée : cotisations sur tout le CA, impôt sur la
  # moitié seulement (abattement micro-BIC).
  def taux_prelevement
    ((taux_cotisations_global + taux_impot * ABATTEMENT_MICRO_BIC) / 100)
  end

  # --- Résultats -------------------------------------------------------------

  def cotisations      = (montant_devis * taux_cotisations_global / 100).round(2)
  def provision_impot  = (montant_devis * ABATTEMENT_MICRO_BIC * taux_impot / 100).round(2)
  def benefice_brut    = (montant_devis - cout_total).round(2)
  def benefice_net     = (benefice_brut - cotisations - provision_impot).round(2)

  def revenu_horaire
    return nil unless heures.positive?
    (benefice_net / heures).round(2)
  end

  def revenu_journalier
    return nil unless revenu_horaire
    (revenu_horaire * heures_par_jour).round(2)
  end

  def marge_pct
    return nil unless montant_devis.positive?
    (benefice_net / montant_devis * 100).round(2)
  end

  def part_materiaux_pct
    return nil unless montant_devis.positive?
    (cout_materiaux / montant_devis * 100).round(2)
  end

  # Prix minimum pour que le chantier atteigne l'objectif horaire NET.
  #
  #   Net = P − coûts − P×t          (t = taux de prélèvement sur le CA)
  #   Net ≥ heures × objectif
  #   ⟹  P ≥ (coûts + heures × objectif) / (1 − t)
  #
  # C'est la division par (1 − t) que le chiffrage actuel oubliait : facturer
  # ses coûts plus sa main-d'œuvre laisse les cotisations à découvert.
  def prix_plancher
    diviseur = 1 - taux_prelevement
    return nil unless diviseur.positive?
    ((cout_total + heures * objectif_horaire) / diviseur).round(2)
  end

  def prix_conseille
    return nil unless prix_plancher
    (prix_plancher * (1 + @a.marge_securite_pct.to_d / 100)).round(2)
  end

  # --- Alertes ---------------------------------------------------------------

  def alertes
    list = []
    if benefice_net.negative?
      list << { niveau: :rouge, code: :benefice_negatif,
                message: "Bénéfice net négatif : ce chantier te coûte de l'argent." }
    end
    if prix_plancher && montant_devis.positive? && montant_devis < prix_plancher
      manque = (prix_plancher - montant_devis).round(2)
      list << { niveau: :rouge, code: :sous_le_plancher,
                message: "Sous le prix plancher de #{eur(manque)} — il faudrait facturer #{eur(prix_plancher)}." }
    end
    if revenu_horaire && objectif_horaire.positive? && revenu_horaire < objectif_horaire
      list << { niveau: :orange, code: :horaire_faible,
                message: "Revenu horaire #{eur(revenu_horaire)}/h, sous ton objectif de #{eur(objectif_horaire)}/h." }
    end
    if marge_pct && marge_pct < @a.seuil_marge_alerte_pct.to_d
      list << { niveau: :orange, code: :marge_faible,
                message: "Marge de #{pct(marge_pct)}, sous ton seuil de #{pct(@a.seuil_marge_alerte_pct)}." }
    end
    if part_materiaux_pct && part_materiaux_pct > @a.part_materiaux_max_pct.to_d
      list << { niveau: :orange, code: :materiaux_lourds,
                message: "Les matériaux pèsent #{pct(part_materiaux_pct)} du devis (seuil #{pct(@a.part_materiaux_max_pct)})." }
    end
    list
  end

  def niveau_global
    return :rouge  if alertes.any? { |a| a[:niveau] == :rouge }
    return :orange if alertes.any?
    :vert
  end

  private

  def eur(v) = "#{format('%.2f', v.to_f).tr('.', ',')} €"
  def pct(v) = "#{format('%.1f', v.to_f).tr('.', ',')} %"
end
