# Une dépense engagée : matériaux, outillage, carburant, sous-traitance.
#
# ⚠️ Aucun effet fiscal. En micro-BIC, l'abattement forfaitaire de 50 %
# remplace les frais réels : ces montants ne réduisent ni l'impôt ni les
# cotisations. Ils servent au PILOTAGE — connaître la marge réelle d'un
# chantier et recaler le barème de rentabilité sur les coûts constatés.
#
# Les montants sont TTC : en franchise en base, la TVA payée au fournisseur
# n'est pas récupérable, elle fait donc partie du coût.
class Depense < ApplicationRecord
  CATEGORIES = {
    "materiaux"      => "Matériaux",
    "outillage"      => "Outillage",
    "carburant"      => "Carburant / déplacement",
    "sous_traitance" => "Sous-traitance",
    "autre"          => "Autre"
  }.freeze

  belongs_to :estimation, optional: true
  has_one_attached :justificatif_image

  validates :date_depense, :libelle, presence: true
  validates :montant, numericality: { greater_than: 0 }
  validates :categorie, inclusion: { in: CATEGORIES.keys }

  scope :chronologique, -> { order(date_depense: :asc, id: :asc) }
  scope :recentes,      -> { order(date_depense: :desc, id: :desc) }
  scope :annee,         ->(a) { where(date_depense: Date.new(a, 1, 1)..Date.new(a, 12, 31)) }
  scope :materiaux,     -> { where(categorie: "materiaux") }
  scope :chantier,      -> { where.not(estimation_id: nil) }
  scope :frais_generaux, -> { where(estimation_id: nil) }

  # Saisie à la française ("128,40") comme partout ailleurs dans l'admin.
  def montant=(val)
    val = val.to_s.tr(",", ".").strip.presence if val.is_a?(String)
    super(val)
  end

  def categorie_label = CATEGORIES[categorie] || categorie

  def justificatif? = justificatif_pdf.present? || justificatif_image.attached?

  # Le blob direct, jamais un variant : les variants Active Storage renvoient
  # une 500 avec le service Cloudinary (cf. Realisation#photo_url).
  def justificatif_image_url
    return nil unless justificatif_image.attached?
    Rails.application.routes.url_helpers.rails_blob_path(justificatif_image, only_path: true)
  end
end
