# Ligne unique de réglages pour la section Déclarations.
class ReglageDeclaration < ApplicationRecord
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
end
