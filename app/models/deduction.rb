class Deduction < ApplicationRecord
  belongs_to :mur

  validates :longueur, :hauteur, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Surface à retirer du mur (ex. porte 0,90 × 2,04 = 1,84 m²).
  def surface
    (longueur.to_d * hauteur.to_d).round(2)
  end
end
