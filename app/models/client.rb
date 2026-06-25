class Client < ApplicationRecord
  STATUTS = {
    "nouveau"      => "Nouveau prospect",
    "contacte"     => "Contacté",
    "rdv_pris"     => "RDV pris",
    "devis_envoye" => "Devis envoyé",
    "gagne"        => "Gagné",
    "perdu"        => "Perdu"
  }.freeze

  has_many :estimations, dependent: :nullify
  has_many :client_notes, dependent: :destroy

  validates :nom,    presence: true, length: { minimum: 2, maximum: 120 }
  # Email optionnel : un client créé à la main (devis manuel, bouche-à-oreille) peut
  # n'avoir qu'un téléphone. Reste unique + au bon format quand il est renseigné.
  validates :email,  uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :statut, inclusion: { in: STATUTS.keys }
  validates :telephone, format: { with: /\A(\+33|0)[1-9](\d{2}){4}\z/, message: "doit être un numéro français valide" }, allow_blank: true

  before_validation :downcase_email

  scope :par_statut,  ->(s) { s.present? ? where(statut: s) : all }
  scope :recents,     -> { order(updated_at: :desc) }
  scope :a_relancer,  -> { where("prochaine_action_date <= ?", Date.current).where.not(statut: %w[gagne perdu]) }

  # Trouve ou crée un client à partir d'une estimation entrante.
  # Met à jour les champs mutables (téléphone/adresse) si vides côté client.
  def self.upsert_from_estimation(estimation)
    client = find_or_initialize_by(email: estimation.email.to_s.downcase.strip)
    client.nom         = estimation.nom         if client.nom.blank?
    client.telephone ||= estimation.telephone
    client.adresse   ||= estimation.adresse
    client.code_postal ||= estimation.code_postal
    client.ville       ||= estimation.ville
    client.statut    ||= "nouveau"
    client.derniere_interaction_at = Time.current
    client.save!
    client
  end

  def statut_label
    STATUTS[statut] || statut.to_s
  end

  # Accepte un montant saisi à la française ("979,80") en plus du format décimal.
  def montant_devis_manuel=(val)
    val = val.to_s.tr(",", ".").strip if val.is_a?(String)
    super(val.presence)
  end

  # Valeur totale des devis du client = devis manuel éventuel + estimations en ligne.
  def total_devis_envoyes
    (montant_devis_manuel || 0) + estimations.sum(:total_ttc)
  end

  def a_relancer?
    return false if %w[gagne perdu].include?(statut)
    prochaine_action_date.present? && prochaine_action_date <= Date.current
  end

  private

  def downcase_email
    self.email = email.to_s.downcase.strip if email.present?
  end
end
