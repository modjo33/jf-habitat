class DeclarationPeriode < ApplicationRecord
  validates :annee, presence: true, numericality: { only_integer: true, greater_than: 2020 }
  validates :trimestre, presence: true, inclusion: { in: 1..4 }
  validates :trimestre, uniqueness: { scope: :annee }
  validates :ca_declare, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :declaree_le, presence: true

  def libelle
    "T#{trimestre} #{annee}"
  end
end
