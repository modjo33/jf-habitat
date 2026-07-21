# Une facture client. Les montants ne sont JAMAIS saisis en dur : le total vient
# des lignes, et le solde du livre des recettes (Encaissement) — une facture est
# « payée » quand ses encaissements couvrent son total.
class Facture < ApplicationRecord
  STATUTS = {
    "brouillon" => "Brouillon",
    "emise"     => "Émise",
    "annulee"   => "Annulée"
  }.freeze

  belongs_to :client
  belongs_to :estimation, optional: true
  has_many :facture_lignes, -> { order(:position, :id) }, dependent: :destroy
  has_many :encaissements, dependent: :nullify

  # Les lignes vierges du formulaire (ajout rapide) sont ignorées.
  accepts_nested_attributes_for :facture_lignes, allow_destroy: true,
    reject_if: ->(attrs) { attrs["libelle"].blank? }

  validates :numero, presence: true, uniqueness: true
  validates :date_emission, presence: true
  validates :statut, inclusion: { in: STATUTS.keys }

  before_validation :attribuer_numero, on: :create
  before_validation :defaut_date, on: :create

  scope :recentes, -> { order(date_emission: :desc, id: :desc) }
  scope :annee, ->(a) { where(date_emission: Date.new(a, 1, 1)..Date.new(a, 12, 31)) }

  def statut_label = STATUTS[statut] || statut

  def total           = facture_lignes.sum(&:total).round(2)
  def montant_encaisse = encaissements.sum(:montant).round(2)
  def solde           = (total - montant_encaisse).round(2)
  def payee?          = total.positive? && solde <= 0
  def acompte?        = montant_encaisse.positive? && !payee?

  # Libellé d'état affiché sur la facture et dans l'admin.
  def etat_reglement
    return "Annulée"        if statut == "annulee"
    return "Payée"          if payee?
    return "Acompte reçu"   if acompte?
    "À régler"
  end

  # Numérotation légale : séquentielle, sans trou, par date d'émission.
  # Format FAC-AAAAMMJJ-NN (cohérent avec les factures déjà émises à la main).
  def self.prochain_numero(date = Date.current)
    base = "FAC-#{date.strftime('%Y%m%d')}"
    rang = where("numero LIKE ?", "#{base}-%").count + 1
    loop do
      candidat = format("%s-%02d", base, rang)
      return candidat unless exists?(numero: candidat)
      rang += 1
    end
  end

  # Crée une facture pré-remplie depuis un devis (lignes libres si présentes,
  # sinon structure pièces/murs du devis terrain).
  def self.depuis_estimation(estimation, date: Date.current)
    facture = new(
      client: estimation.client,
      estimation: estimation,
      date_emission: date,
      objet: "Travaux — devis #{estimation.reference}",
      chantier_adresse: [estimation.adresse, "#{estimation.code_postal} #{estimation.ville}".strip]
                          .reject(&:blank?).join(", "),
      conditions: estimation.devis_conditions.presence
    )
    lignes_depuis(estimation).each_with_index do |attrs, i|
      facture.facture_lignes.build(attrs.merge(position: i))
    end
    facture
  end

  def self.lignes_depuis(estimation)
    if estimation.devis_lignes.exists?
      estimation.devis_lignes.ordered.map do |l|
        { section: l.section, libelle: l.libelle, description: l.description,
          quantite: l.quantite, unite: l.unite, prix_unitaire: l.prix_unitaire }
      end
    else
      lignes_depuis_murs(estimation)
    end
  end

  # Devis terrain : une ligne de peinture par mur + une ligne par forfait
  # exceptionnel (ponçage / rebouchage / ratissage), groupées par pièce.
  def self.lignes_depuis_murs(estimation)
    lignes = []
    estimation.pieces.includes(:murs).each do |piece|
      piece.murs.each do |mur|
        next unless mur.total.to_d.positive?
        if mur.peinture_total.to_d.positive?
          lignes << { section: piece.nom, libelle: "#{mur.prestation_label} — #{mur.libelle}",
                      description: [mur.gamme_label, mur.type_chantier_label].compact_blank.join(" · "),
                      quantite: mur.surface_nette, unite: "m2", prix_unitaire: mur.prix_peinture_m2 }
        end
        { poncage: "Ponçage / égrenage", rebouchage: "Rebouchage",
          ratissage: "Ratissage" }.each do |champ, label|
          forfait = mur.public_send("#{champ}_forfait").to_d
          next unless forfait.positive?
          lignes << { section: piece.nom, libelle: "#{label} — #{mur.libelle}",
                      description: "Travaux préparatoires exceptionnels",
                      quantite: nil, unite: "forfait", prix_unitaire: forfait }
        end
      end
    end
    if estimation.devis_trajet_total.to_d.positive?
      lignes << { section: "Frais de chantier", libelle: "Déplacement",
                  quantite: nil, unite: "forfait", prix_unitaire: estimation.devis_trajet_total }
    end
    if estimation.devis_consommables.to_d.positive?
      lignes << { section: "Frais de chantier",
                  libelle: estimation.devis_consommables_libelle.presence || "Consommables",
                  quantite: nil, unite: "forfait", prix_unitaire: estimation.devis_consommables }
    end
    lignes
  end

  def regenerer_pdf!
    pdf = FacturePdfGenerator.new(self).generate
    update_columns(pdf_data: pdf.render, pdf_genere_at: Time.current)
  end

  # Le PDF affiche le solde : il périme dès qu'une ligne change ou qu'un
  # règlement est encaissé. Sans ça, on enverrait au client un « solde à
  # régler » obsolète (montant total alors qu'un acompte a été versé).
  def pdf_a_jour?
    return false if pdf_data.blank? || pdf_genere_at.blank?

    dernier = [updated_at,
               facture_lignes.maximum(:updated_at),
               encaissements.maximum(:updated_at)].compact.max
    dernier.nil? || dernier <= pdf_genere_at
  end

  def pdf_frais
    regenerer_pdf! unless pdf_a_jour?
    pdf_data
  end

  private

  def attribuer_numero
    self.numero = self.class.prochain_numero(date_emission || Date.current) if numero.blank?
  end

  def defaut_date
    self.date_emission ||= Date.current
  end
end
