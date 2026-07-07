# Ligne unique : suivi de la campagne Google Ads (saisie manuelle de la dépense).
class CampagneAds < ApplicationRecord
  validates :budget_total, :depense_cumulee, :cout_journalier,
            numericality: { greater_than_or_equal_to: 0 }

  def self.instance
    first_or_create!
  end

  # Accepte les montants saisis à la française ("123,45").
  %i[budget_total depense_cumulee cout_journalier].each do |champ|
    define_method("#{champ}=") do |val|
      val = val.to_s.tr(",", ".").strip if val.is_a?(String)
      super(val.presence)
    end
  end

  def pourcentage
    return 0 if budget_total.to_f.zero?
    [(depense_cumulee.to_f / budget_total.to_f * 100).round, 100].min
  end

  def budget_restant
    (budget_total.to_f - depense_cumulee.to_f).round(2)
  end

  # Nombre de jours de diffusion encore couverts par le budget restant.
  def jours_budget_restant
    return nil if cout_journalier.to_f.zero?
    [(budget_restant / cout_journalier.to_f).floor, 0].max
  end

  def jours_avant_validation
    return nil unless validation_deadline
    (validation_deadline - Date.current).to_i
  end

  # :ok / :surveiller / :critique — pilote la couleur de la jauge et le bandeau.
  def niveau
    j = jours_avant_validation
    return :critique if pourcentage >= 90 || (j && j <= 3)
    return :surveiller if pourcentage >= 70 || (j && j <= 10)
    :ok
  end

  def alerte?
    active? && niveau != :ok
  end
end
