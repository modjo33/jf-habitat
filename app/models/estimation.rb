class Estimation < ApplicationRecord
  STATUTS = %w[nouveau contacte devis_envoye gagne perdu].freeze
  DELAIS = {
    "urgent"       => "Dès que possible",
    "1_3_mois"     => "Dans 1 à 3 mois",
    "3_6_mois"     => "Dans 3 à 6 mois",
    "6_12_mois"    => "Dans 6 à 12 mois",
    "reflexion"    => "Je me renseigne"
  }.freeze

  TYPES_CHANTIER = {
    "renovation"   => "Rénovation",
    "neuf"         => "Construction neuve"
  }.freeze

  # Coefficient régional par préfixe département
  COEFFICIENTS_REGION = {
    paris_intra:    { cp: %w[75], coef: 1.20, label: "Paris intra-muros" },
    petite_couronne:{ cp: %w[92 93 94], coef: 1.15, label: "Petite couronne parisienne" },
    grande_couronne:{ cp: %w[77 78 91 95], coef: 1.08, label: "Grande couronne parisienne" },
    grandes_villes: { cp: %w[06 13 33 59 69 31 67 44], coef: 1.05, label: "Grandes métropoles" }
  }.freeze

  # Tarifs dégressifs par surface totale
  SEUILS_REMISE = [
    { seuil_m2: 200, remise: 0.15 },
    { seuil_m2: 100, remise: 0.10 }
  ].freeze

  belongs_to :client, optional: true
  has_many :estimation_lines, dependent: :destroy
  has_many_attached :photos
  accepts_nested_attributes_for :estimation_lines, allow_destroy: true

  validates :nom, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :telephone, presence: true, format: { with: /\A(\+33|0)[1-9](\d{2}){4}\z/, message: "doit être un numéro français valide" }
  validates :reference, presence: true, uniqueness: true
  validates :statut, inclusion: { in: STATUTS }
  validates :delai, inclusion: { in: DELAIS.keys }, allow_blank: true
  validates :type_chantier, inclusion: { in: TYPES_CHANTIER.keys }, allow_blank: true
  validates :etage, numericality: { greater_than_or_equal_to: 0, less_than: 30 }
  validate :photos_valides
  validate :au_moins_une_ligne

  before_validation :generer_reference, on: :create
  before_save :calculer_coefficients
  before_save :recalculer_totaux

  def recalculer_totaux
    self.surface_totale = estimation_lines.reject(&:marked_for_destruction?).sum { |l| l.surface.to_d }

    # Tarif dégressif selon surface totale
    self.remise_degressive = SEUILS_REMISE.detect { |s| surface_totale >= s[:seuil_m2] }&.dig(:remise) || 0

    sous_total = estimation_lines.reject(&:marked_for_destruction?).sum { |l| l.total.to_d }
    # Application des coefficients multiplicatifs et de la remise dégressive
    apres_coefs = sous_total * coef_region.to_d * coef_etage.to_d
    apres_remise = apres_coefs * (1 - remise_degressive.to_d)

    self.total_ht = apres_remise.round(2)
    self.total_ttc = (total_ht * (1 + tva_taux / 100)).round(2)
  end

  def calculer_coefficients
    self.coef_region = calculer_coef_region
    self.coef_etage  = calculer_coef_etage
  end

  def delai_label
    DELAIS[delai] || delai.presence || "Non précisé"
  end

  def type_chantier_label
    TYPES_CHANTIER[type_chantier] || type_chantier
  end

  def coef_region_label
    return "Tarif standard" if coef_region.to_d == 1.0
    zone = COEFFICIENTS_REGION.values.find { |z| z[:coef].to_d == coef_region.to_d }
    zone ? "#{zone[:label]} (+#{((coef_region.to_d - 1) * 100).to_i}%)" : "Coefficient régional +#{((coef_region.to_d - 1) * 100).to_i}%"
  end

  def coef_etage_label
    return "RDC / 1er / 2ème" if coef_etage.to_d == 1.0
    pct = ((coef_etage.to_d - 1) * 100).to_i
    "Étage ≥3 #{ascenseur ? 'avec ascenseur' : 'sans ascenseur'} (+#{pct}%)"
  end

  private

  def calculer_coef_region
    return 1.0 if code_postal.blank?
    dept = code_postal.to_s.strip[0, 2]
    zone = COEFFICIENTS_REGION.values.find { |z| z[:cp].include?(dept) }
    zone ? zone[:coef] : 1.0
  end

  def calculer_coef_etage
    return 1.0 if etage.to_i <= 2
    ascenseur? ? 1.03 : 1.10
  end

  def generer_reference
    return if reference.present?
    loop do
      self.reference = "BF-#{Time.current.strftime('%y%m')}-#{SecureRandom.alphanumeric(6).upcase}"
      break unless self.class.exists?(reference: reference)
    end
  end

  def photos_valides
    return unless photos.attached?
    photos.each do |photo|
      if photo.blob.byte_size > 10.megabytes
        errors.add(:photos, "doit faire moins de 10 Mo (#{photo.filename})")
      end
      unless %w[image/jpeg image/png image/webp image/heic].include?(photo.blob.content_type)
        errors.add(:photos, "doit être une image JPG, PNG, WEBP ou HEIC")
      end
    end
  end

  def au_moins_une_ligne
    return if estimation_lines.reject(&:marked_for_destruction?).any?
    errors.add(:base, "Ajoutez au moins une pièce / prestation à votre estimation.")
  end
end
