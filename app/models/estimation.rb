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

  # Modèles d'échéancier pré-remplis, sélectionnables dans l'éditeur de devis
  # pour éviter de tout retaper. Une échéance sans `pct` = « le reste » (solde).
  CONDITIONS_PRESETS = [
    { label: "30 % à la commande, solde à réception",
      echeances: [{ libelle: "Acompte à la commande", pct: 30 },
                  { libelle: "Solde à la réception des travaux", pct: nil }] },
    { label: "40 % à la commande, solde en fin de chantier",
      echeances: [{ libelle: "Acompte à la commande", pct: 40 },
                  { libelle: "Solde à la fin des travaux", pct: nil }] },
    { label: "30 % début, 20 % milieu, solde à la fin",
      echeances: [{ libelle: "À la signature / début de chantier", pct: 30 },
                  { libelle: "En milieu de chantier", pct: 20 },
                  { libelle: "Solde à la fin du chantier", pct: nil }] },
    { label: "50 % / 50 %",
      echeances: [{ libelle: "Acompte à la commande", pct: 50 },
                  { libelle: "Solde à la fin du chantier", pct: nil }] },
    { label: "Paiement intégral à réception",
      echeances: [{ libelle: "Paiement à la réception des travaux", pct: nil }] }
  ].freeze

  belongs_to :client, optional: true
  has_many :estimation_lines, dependent: :destroy
  has_many :pieces, -> { order(:position, :id) }, dependent: :destroy
  has_many :devis_lignes, -> { order(:position, :id) }, dependent: :destroy
  has_many_attached :photos
  has_one_attached :devis_signature
  # PDF du devis prêt à envoyer, stocké en base (table dédiée) plutôt que sur
  # Cloudinary (qui bloque la livraison des fichiers PDF).
  has_one :devis_document, dependent: :destroy
  # Analyse de rentabilité interne (jamais exposée au client).
  has_one :devis_analyse, dependent: :destroy
  # Dépenses réellement engagées sur ce chantier.
  has_many :depenses, dependent: :nullify
  accepts_nested_attributes_for :estimation_lines, allow_destroy: true

  validates :nom, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :telephone, presence: true, format: { with: /\A(\+33|0)[1-9](\d{2}){4}\z/, message: "doit être un numéro français valide" }
  # Exigé à la CRÉATION seulement : il dit si le chantier est dans la zone et
  # porte le coefficient régional. `on: :create` pour ne pas bloquer la mise à
  # jour des estimations d'avant cette règle, qui n'en ont pas (changer un
  # statut depuis l'admin échouerait sinon).
  validates :code_postal, presence: true, on: :create
  validates :code_postal, format: { with: /\A\d{5}\z/, message: "doit comporter 5 chiffres" }, allow_blank: true
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

  # ------------------------------------------------------------------
  # TVA — franchise en base (art. 293 B du CGI)
  # ------------------------------------------------------------------
  # L'entreprise ne collecte pas de TVA : l'afficher sur l'estimation revenait
  # à annoncer au client 10 % de plus que le devis qu'il recevrait ensuite, et
  # à mentionner une taxe qui n'est jamais facturée. Le taux reste une donnée
  # de l'estimation — le jour de l'assujettissement, le repasser à 10 suffit à
  # faire réapparaître la ventilation partout (page devis, PDF, mails).
  MENTION_TVA = "TVA non applicable, art. 293 B du CGI".freeze

  def tva_applicable?
    tva_taux.to_d.positive?
  end

  def montant_tva
    (total_ttc.to_d - total_ht.to_d).round(2)
  end

  # « Total TTC » n'a de sens que si une TVA est effectivement collectée.
  def total_label
    tva_applicable? ? "Total TTC" : "Total"
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
    brut =
      if devis_lignes.exists?
        # Nouveau modèle : lignes de devis libres.
        devis_lignes.each { |l| l.update_columns(total: l.total_calc) }
        devis_lignes.sum(:total).to_d.round(2)
      else
        # Ancien modèle assisté : pièces → murs.
        pieces.includes(murs: %i[deductions zones]).each do |piece|
          piece.murs.each do |m|
            m.update_columns(surface_nette: m.surface_nette_calc, total: m.total_calc)
          end
          piece.update_column(:total, piece.murs.sum { |m| m.total.to_d }.round(2))
        end
        pieces.sum { |p| p.total.to_d }.round(2)
      end
    # La remise s'applique au sous-total complet (travaux + trajet + consommables).
    sous_total = brut + devis_extras_total
    total      = [sous_total - devis_remise_for(sous_total), 0.to_d].max.round(2)
    update_columns(devis_total_brut: brut, devis_total: total)
    # Le verdict de rentabilité dépend du montant : il périme dès que le devis
    # change. On le rafraîchit ici plutôt que de recalculer à l'affichage.
    devis_analyse&.rafraichir!
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

  # ---- Origine du lead ------------------------------------------------------

  # Un gclid ne peut venir que d'un clic sur une annonce Google Ads.
  def issu_de_google_ads?
    gclid.present? || utm_source.to_s.casecmp?("google") && utm_medium.to_s.casecmp?("cpc")
  end

  # Libellé court pour le CRM. `nil` = lead antérieur au tracking (18/07/2026)
  # ou visiteur sans marqueur de campagne (direct / SEO / lien externe).
  def source_label
    return "Google Ads" if issu_de_google_ads?
    return "#{utm_source} · #{utm_medium}".strip.delete_suffix(" ·") if utm_source.present?
    return "Référent : #{URI.parse(referrer).host}" if referrer.present? && (URI.parse(referrer).host rescue nil)
    nil
  rescue URI::InvalidURIError
    nil
  end

  def source_details
    {
      "Campagne" => utm_campaign,
      "Mot-clé"  => utm_term,
      "Contenu"  => utm_content,
      "Atterrissage" => landing_page,
      "gclid"    => gclid
    }.compact_blank
  end

  # Un devis « en lignes libres » (Vague 1) plutôt que le devis assisté pièce/mur.
  def devis_lignes?
    devis_lignes.exists?
  end

  # Générateur PDF adapté au type de devis (lignes libres vs pièces/murs).
  def devis_pdf_generator
    (devis_lignes? ? DevisLignePdfGenerator : DevisTerrainPdfGenerator).new(self)
  end

  # ------------------------------------------------------------------
  # Vie du devis : construit → envoyé → accepté
  # ------------------------------------------------------------------
  DEVIS_ETATS = {
    "brouillon" => "En préparation",
    "envoye"    => "Envoyé au client",
    "accepte"   => "Accepté",
    "refuse"    => "Refusé"
  }.freeze

  # Les devis réellement chiffrés — ceux qui méritent de figurer dans la liste.
  scope :avec_devis, -> { where("devis_total > 0") }

  def devis_existe?
    devis_total.to_d.positive?
  end

  # La signature à l'écran vaut acceptation : elle précède l'existence de
  # `devis_accepte_at` et reste le cas le plus fréquent (signature sur place).
  def devis_etat
    return "accepte" if devis_accepte_at.present? || devis_signe_at.present?
    return "refuse"  if statut == "perdu"
    return "envoye"  if devis_envoye_at.present?

    "brouillon"
  end

  def devis_etat_label = DEVIS_ETATS[devis_etat]
  def devis_accepte?   = devis_etat == "accepte"

  # Accepter un devis renvoyé signé par mail ou validé au téléphone : c'est ce
  # geste qui fait entrer le montant dans le CA gagné du tableau de bord, via
  # le passage du client en « gagné » (cf. Client.ca_devis).
  def accepter_devis!(date: Time.current)
    transaction do
      update_columns(devis_accepte_at: date, statut: "gagne", updated_at: Time.current)
      # Le CA gagné du tableau de bord s'agrège par CLIENT (Client.ca_devis) :
      # une estimation acceptée sans fiche client resterait invisible dans les
      # chiffres. On rattache donc la fiche si elle manque.
      rattacher_client if client.blank? && email.present?
      client&.update(statut: "gagne")
    end
    devis_analyse&.rafraichir!
    self
  end

  def rattacher_client
    fiche = Client.upsert_from_estimation(self)
    update_column(:client_id, fiche.id)
    reload_client
    fiche
  rescue => e
    Rails.logger.warn "[Estimation##{id}] rattachement client impossible : #{e.class} · #{e.message}"
    nil
  end

  def rouvrir_devis!
    update_columns(devis_accepte_at: nil, statut: "devis_envoye", updated_at: Time.current)
    devis_analyse&.rafraichir!
    self
  end

  # Un devis ouvert mais jamais chiffré : cliquer « Devis assisté » crée déjà
  # une pièce, sans le moindre mur. Le total vaut alors 0 € et le PDF sort à
  # 0 € — sans rapport avec le chiffrage web du client, qui lui est bien réel.
  # Aucun document à 0 € ne doit pouvoir être présenté, signé ou envoyé.
  def devis_vide?
    devis_total.to_d <= 0
  end

  # Acompte à la commande demandé (€), calculé sur le total du devis.
  def devis_acompte_montant
    return 0.to_d if devis_acompte_pct.to_i <= 0
    (devis_total.to_d * devis_acompte_pct.to_i / 100).round(2)
  end

  # Solde restant dû après l'acompte.
  def devis_solde_montant
    (devis_total.to_d - devis_acompte_montant).round(2)
  end

  # Un échéancier de paiement est renseigné (au moins une ligne avec un libellé).
  def devis_echeancier?
    Array(devis_echeances).any? { |e| e["libelle"].to_s.strip.present? }
  end

  # Échéancier calculé : chaque versement avec son montant en €. Une ligne sans
  # pourcentage vaut « le reste » (total − somme des versements chiffrés).
  def devis_echeances_list
    rows = Array(devis_echeances).select { |e| e["libelle"].to_s.strip.present? || e["pct"].to_s.strip.present? }
    return [] if rows.empty?

    total    = devis_total.to_d
    attribue = rows.sum { |e| e["pct"].to_s.strip.present? ? (total * e["pct"].to_d / 100) : 0.to_d }
    rows.map do |e|
      pct_present = e["pct"].to_s.strip.present?
      {
        libelle: e["libelle"].to_s.strip,
        pct:     pct_present ? e["pct"].to_d : nil,
        montant: pct_present ? (total * e["pct"].to_d / 100).round(2) : (total - attribue).round(2)
      }
    end
  end

  # Montant retenu pour le chiffre d'affaires : le devis terrain (montant réel
  # négocié) dès qu'il existe, sinon le chiffrage web (total_ttc).
  def ca_montant
    devis_total.to_d.positive? ? devis_total.to_d : total_ttc.to_d
  end

  # Analyse de rentabilité — INTERNE, jamais rendue sur un document client.
  def analyse_rentabilite
    devis_analyse || create_devis_analyse!
  end

  # Version agrégée (SQL) — utilisable sur une relation : Estimation.where(...).ca_montant.
  def self.ca_montant
    sum(Arel.sql("CASE WHEN devis_total > 0 THEN devis_total ELSE total_ttc END")).to_d
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
