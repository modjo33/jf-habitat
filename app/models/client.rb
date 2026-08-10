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
  has_many :encaissements, dependent: :nullify

  validates :nom,    presence: true, length: { minimum: 2, maximum: 120 }
  # Email optionnel : un client créé à la main (devis manuel, bouche-à-oreille) peut
  # n'avoir qu'un téléphone. Reste unique + au bon format quand il est renseigné.
  validates :email,  uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :statut, inclusion: { in: STATUTS.keys }
  validates :telephone, format: { with: /\A(\+33|0)[1-9](\d{2}){4}\z/, message: "doit être un numéro français valide" }, allow_blank: true

  before_validation :downcase_email
  before_validation :nettoyer_espaces

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

  # Valeur totale des devis du client. `montant_devis_manuel` sert aux devis
  # faits HORS estimateur ; dès qu'une estimation porte un devis chiffré, le
  # montant manuel est presque toujours le même montant ressaisi à la main —
  # l'additionner comptait le chantier deux fois (fiche client ET CA gagné).
  def total_devis_envoyes
    estimations.ca_montant + montant_devis_manuel_net
  end

  # Le devis manuel n'est retenu que s'il n'est pas déjà couvert par un devis
  # terrain porté par une estimation du client.
  def montant_devis_manuel_net
    return 0.to_d if montant_devis_manuel.blank?
    return 0.to_d if devis_terrain?
    montant_devis_manuel.to_d
  end

  # Au moins une estimation avec un devis terrain chiffré.
  def devis_terrain?
    estimations.where("devis_total > 0").exists?
  end

  # Doublon probable à signaler dans l'admin : un montant manuel saisi alors
  # qu'un devis terrain existe déjà.
  def devis_manuel_ignore?
    montant_devis_manuel.to_d.positive? && devis_terrain?
  end

  # Agrégat SQL équivalent à la somme des `total_devis_envoyes`, sans doublon :
  # devis manuels des clients qui n'ont AUCUN devis terrain, + devis/estimations.
  def self.ca_devis(scope = all)
    ids = scope.pluck(:id)
    return 0.to_d if ids.empty?
    avec_devis = Estimation.where(client_id: ids).where("devis_total > 0").distinct.pluck(:client_id)
    manuels = where(id: ids - avec_devis).sum(:montant_devis_manuel).to_d
    manuels + Estimation.where(client_id: ids).ca_montant
  end

  def a_relancer?
    return false if %w[gagne perdu].include?(statut)
    prochaine_action_date.present? && prochaine_action_date <= Date.current
  end

  # Adresse sur une ligne, pour pré-remplir un RDV.
  def adresse_complete
    [adresse, [code_postal, ville].compact_blank.join(" ")].compact_blank.join(", ")
  end

  private

  def downcase_email
    self.email = email.to_s.downcase.strip if email.present?
  end

  # Une espace invisible en début de champ ne se voit pas dans l'admin mais
  # casse tout ce qui lit la valeur : un code postal saisi « 33140 » avec une
  # espace devant a bloqué la création d'un devis, la validation « 5 chiffres »
  # de l'estimation le refusant sans qu'on comprenne pourquoi.
  def nettoyer_espaces
    %i[nom telephone adresse code_postal ville].each do |champ|
      valeur = send(champ)
      send("#{champ}=", valeur.strip) if valeur.is_a?(String) && valeur != valeur.strip
    end
  end
end
