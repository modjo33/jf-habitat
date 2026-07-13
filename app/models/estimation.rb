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

  DEVIS_REMISE_TYPES = %w[pourcentage montant].freeze

  belongs_to :client, optional: true
  has_many :estimation_lines, dependent: :destroy
  has_many :pieces, -> { order(:position, :id) }, dependent: :destroy
  has_many_attached :photos
  has_one_attached :devis_signature
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

    sous_total = estimation_lines.reject(&:marked_for_destruction?).sum { |l| l.total.to_d }
    # Application des coefficients multiplicatifs (région, étage).
    self.total_ht  = (sous_total * coef_region.to_d * coef_etage.to_d).round(2)
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

  # ------------------------------------------------------------------
  # Devis terrain (outil admin, tablette). Totaux indépendants du
  # chiffrage web (total_ht/total_ttc) ; franchise en base → pas de TVA.
  # ------------------------------------------------------------------

  # Recalcul bottom-up : murs → pièces → total devis. Écrit en base via
  # update_columns pour ne pas déclencher les callbacks du chiffrage web.
  def devis_recompute!
    pieces.includes(murs: %i[deductions zones]).each do |piece|
      piece.murs.each do |m|
        m.update_columns(surface_nette: m.surface_nette_calc, total: m.total_calc)
      end
      piece.update_column(:total, piece.murs.sum { |m| m.total.to_d }.round(2))
    end
    brut       = pieces.sum { |p| p.total.to_d }.round(2)
    # La remise s'applique au sous-total complet (travaux + trajet + consommables).
    sous_total = brut + devis_extras_total
    total      = [sous_total - devis_remise_for(sous_total), 0.to_d].max.round(2)
    update_columns(devis_total_brut: brut, devis_total: total)
    total
  end

  # Sous-total avant remise : travaux + frais (trajet + consommables).
  def devis_sous_total
    (devis_total_brut.to_d + devis_extras_total).round(2)
  end

  # Frais de déplacement : prix/jour × nombre de jours.
  def devis_trajet_total
    (devis_trajet_prix_jour.to_d * devis_trajet_jours.to_d).round(2)
  end

  # Total des frais ajoutés au chantier (trajet + consommables).
  def devis_extras_total
    (devis_trajet_total + devis_consommables.to_d).round(2)
  end

  # Montant € de la remise appliquée (sur le sous-total : travaux + frais).
  def devis_remise_montant
    devis_remise_for(devis_sous_total)
  end

  # Adresse chantier sur une ligne (pour pré-remplir un RDV).
  def adresse_complete
    [adresse, [code_postal, ville].compact_blank.join(" ")].compact_blank.join(", ")
  end

  def devis_signe?
    devis_signe_at.present? && devis_signature.attached?
  end

  # Montant retenu pour le chiffre d'affaires : le devis terrain **signé** s'il
  # existe (montant réel négocié sur place), sinon le chiffrage web (total_ttc).
  def ca_montant
    devis_signe_at.present? ? devis_total.to_d : total_ttc.to_d
  end

  # Version agrégée (SQL) — utilisable sur une relation : Estimation.where(...).ca_montant.
  def self.ca_montant
    sum(Arel.sql("CASE WHEN devis_signe_at IS NOT NULL THEN devis_total ELSE total_ttc END")).to_d
  end

  # Enregistre la signature du client, verrouille le devis et passe le lead
  # (et le client) en « gagné ». `signature_io` = flux binaire PNG décodé.
  def finaliser_devis_signe!(signature_io:, signataire:, ip:)
    devis_recompute!
    devis_signature.attach(io: signature_io, filename: "signature-#{reference}.png", content_type: "image/png")
    update!(devis_signataire: signataire.presence || nom,
            devis_signature_ip: ip, devis_signe_at: Time.current, statut: "gagne")
    client&.update(statut: "gagne") if client && client.statut != "gagne"
  end

  # Crée une pièce par local distinct de l'estimation web (nom + hauteur par
  # défaut). L'artisan y ajoutera les murs avec les vraies mesures. Idempotent.
  def devis_prefill_from_web!
    return if pieces.exists?

    noms = estimation_lines.map { |l| [l.piece, l.type_piece] }.uniq
    noms = [["Pièce 1", "autre"]] if noms.empty?
    noms.each_with_index do |(nom, type_piece), i|
      pieces.create!(nom: nom.presence || "Pièce #{i + 1}",
                     type_piece: type_piece.presence || "autre",
                     hauteur_sous_plafond: 2.5, position: i)
    end
    update_columns(devis_actif: true)
  end

  private

  # Remise en euros calculée sur un total brut donné.
  def devis_remise_for(brut)
    brut = brut.to_d
    return 0.to_d if devis_remise_type.blank? || devis_remise_valeur.to_d <= 0

    case devis_remise_type
    when "pourcentage" then (brut * devis_remise_valeur.to_d / 100).round(2)
    when "montant"     then [devis_remise_valeur.to_d, brut].min
    else 0.to_d
    end
  end

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
