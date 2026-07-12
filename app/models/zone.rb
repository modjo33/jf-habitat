class Zone < ApplicationRecord
  belongs_to :mur

  validates :longueur, :largeur, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Surface d'une partie de plafond (rectangle longueur × largeur).
  def surface
    (longueur.to_d * largeur.to_d).round(2)
  end
end
