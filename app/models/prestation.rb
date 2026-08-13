# Bibliothèque d'actions réutilisables : une prestation type (libellé, description,
# unité, prix) qu'on insère dans un devis en un clic, puis qu'on ajuste.
class Prestation < ApplicationRecord
  UNITES = { "m2" => "m²", "ml" => "ml", "u" => "u", "forfait" => "forfait" }.freeze
  CATEGORIES = {
    "protection"  => "Protection",
    "preparation" => "Préparation",
    "peinture"    => "Peinture",
    "placo"       => "Placo / cloisons",
    "revetement"  => "Revêtement (sol…)",
    "divers"      => "Divers"
  }.freeze

  validates :nom, presence: true
  validates :unite, inclusion: { in: UNITES.keys }
  validates :categorie, inclusion: { in: CATEGORIES.keys }
  validates :prix, numericality: { greater_than_or_equal_to: 0 }

  scope :actives, -> { where(actif: true) }
  scope :ordered, -> { order(:categorie, :position, :nom) }

  def unite_label     = UNITES[unite] || unite
  def categorie_label = CATEGORIES[categorie] || categorie
  def forfait?        = unite == "forfait"
end
