# Une ligne de facture — même contrat que DevisLigne : quantité × prix, ou
# total = prix quand l'unité est « forfait ». Regroupées par `section`.
class FactureLigne < ApplicationRecord
  belongs_to :facture

  UNITES = Prestation::UNITES

  validates :libelle, presence: true
  validates :unite, inclusion: { in: UNITES.keys }
  validates :quantite, :prix_unitaire, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_save :recalculer

  scope :ordered, -> { order(:position, :id) }

  def forfait?    = unite == "forfait"
  def unite_label = UNITES[unite] || unite

  def total_calc
    return prix_unitaire.to_d.round(2) if forfait?
    (quantite.to_d * prix_unitaire.to_d).round(2)
  end

  # Saisie à la française ("22,50") comme partout ailleurs dans l'admin.
  def quantite=(val)
    super(normaliser(val))
  end

  def prix_unitaire=(val)
    super(normaliser(val))
  end

  private

  def normaliser(val)
    val.is_a?(String) ? val.tr(",", ".").strip.presence : val
  end

  def recalculer
    self.total = total_calc
  end
end
