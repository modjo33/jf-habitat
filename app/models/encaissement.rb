class Encaissement < ApplicationRecord
  MODES = {
    "virement" => "Virement",
    "cheque"   => "Chèque",
    "especes"  => "Espèces",
    "cb"       => "Carte bancaire"
  }.freeze

  belongs_to :client, optional: true

  validates :date_encaissement, presence: true
  validates :libelle, presence: true, length: { maximum: 200 }
  validates :montant, presence: true, numericality: { greater_than: 0 }
  validates :mode_reglement, inclusion: { in: MODES.keys }

  scope :chronologique, -> { order(date_encaissement: :asc, id: :asc) }
  scope :recents,       -> { order(date_encaissement: :desc, id: :desc) }
  scope :annee,     ->(a)    { where(date_encaissement: Date.new(a, 1, 1)..Date.new(a, 12, 31)) }
  scope :trimestre, ->(a, t) { where(date_encaissement: Date.new(a, (t - 1) * 3 + 1, 1)..Date.new(a, (t - 1) * 3 + 1, 1).end_of_quarter) }
  scope :mois,      ->(a, m) { where(date_encaissement: Date.new(a, m, 1)..Date.new(a, m, 1).end_of_month) }

  # Accepte un montant saisi à la française ("979,80"), comme Client#montant_devis_manuel.
  def montant=(val)
    val = val.to_s.tr(",", ".").strip if val.is_a?(String)
    super(val.presence)
  end

  def mode_reglement_label
    MODES[mode_reglement] || mode_reglement
  end
end
