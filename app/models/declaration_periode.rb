class DeclarationPeriode < ApplicationRecord
  validates :annee, presence: true, numericality: { only_integer: true, greater_than: 2020 }
  # `trimestre` porte le NUMÉRO de période : 1-12 au mois, 1-4 au trimestre.
  validates :trimestre, presence: true, inclusion: { in: 1..12 }
  validates :trimestre, uniqueness: { scope: %i[annee periodicite] }
  validates :periodicite, inclusion: { in: ReglageDeclaration::PERIODICITES.keys }
  validates :ca_declare, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :declaree_le, presence: true

  def mensuelle? = periodicite == "mensuelle"

  def libelle
    return I18n.l(Date.new(annee, trimestre, 1), format: "%B %Y").capitalize if mensuelle?

    "T#{trimestre} #{annee}"
  end
end
