# Ligne unique de réglages pour la section Déclarations.
class ReglageDeclaration < ApplicationRecord
  # L'URSSAF laisse choisir à l'inscription : mensuelle ou trimestrielle.
  # Le module supposait le trimestre pour tout le monde et annonçait donc de
  # fausses échéances à qui déclare au mois.
  PERIODICITES = { "mensuelle" => "Mensuelle", "trimestrielle" => "Trimestrielle" }.freeze

  validates :periodicite_urssaf, inclusion: { in: PERIODICITES.keys }

  def mensuelle?      = periodicite_urssaf == "mensuelle"
  def periodicite_label = PERIODICITES[periodicite_urssaf]

  validates :taux_cotisations, :taux_cfp, :taux_cma,
            numericality: { greater_than_or_equal_to: 0, less_than: 100 }
  validates :are_mensuelle, :allocation_journaliere,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  def self.instance
    first_or_create!(fin_droits_are: Date.new(2026, 9, 15))
  end

  # Taux global appliqué au CA déclaré (cotisations + CFP + taxe CMA,
  # + versement libératoire de l'impôt si l'option est active).
  def taux_global
    taux_cotisations + taux_cfp + taux_cma + (versement_liberatoire? ? 1.7 : 0)
  end

  def are_active?(date = Date.current)
    fin_droits_are.nil? || date <= fin_droits_are
  end

  # --- Rentabilité -----------------------------------------------------------

  # Ce que le chantier doit rapporter net de l'heure. Soit forcé à la main,
  # soit déduit du revenu mensuel visé et du temps réellement travaillé.
  def objectif_horaire(date = Date.current)
    return objectif_horaire_force.to_d if objectif_horaire_force.to_d.positive?
    heures = heures_travaillees_mois
    return 0.to_d if heures.zero?
    (besoin_mensuel(date) / heures).round(2)
  end

  # Besoin de revenu à couvrir par l'activité. Tant que l'ARE tombe, elle en
  # couvre une partie — d'où un objectif horaire plus bas jusqu'à la fin des
  # droits, et plus élevé après.
  def besoin_mensuel(date = Date.current)
    cible = revenu_mensuel_cible.to_d
    return cible unless deduire_are? && are_active?(date)
    [cible - are_mensuelle.to_d, 0.to_d].max
  end

  def heures_travaillees_mois
    (jours_travailles_mois.to_d * heures_par_jour.to_d)
  end

  # Part du CA effectivement prélevée : cotisations + impôt sur le revenu
  # imposable (50 % du CA en micro-BIC services, abattement forfaitaire).
  ABATTEMENT_MICRO_BIC = 0.5

  def taux_prelevement_global
    (taux_global.to_d + taux_impot.to_d * ABATTEMENT_MICRO_BIC) / 100
  end
end
