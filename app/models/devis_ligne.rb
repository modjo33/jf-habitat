# Une ligne d'un devis : libellé + description + quantité × unité × prix → total.
# Unité "forfait" → total = prix (quantité ignorée). Regroupées par `section`.
class DevisLigne < ApplicationRecord
  belongs_to :estimation
  belongs_to :prestation, optional: true

  UNITES = Prestation::UNITES

  validates :libelle, presence: true
  validates :unite, inclusion: { in: UNITES.keys }
  validates :quantite, :prix_unitaire, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_save :recalculer

  scope :ordered, -> { order(:position, :id) }

  def forfait?     = unite == "forfait"
  def unite_label  = UNITES[unite] || unite

  def total_calc
    return prix_unitaire.to_d.round(2) if forfait?
    (quantite.to_d * prix_unitaire.to_d).round(2)
  end

  private

  def recalculer
    self.total = total_calc
  end
end
