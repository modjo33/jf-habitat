class Mur < ApplicationRecord
  belongs_to :piece
  has_many :deductions, -> { order(:position, :id) }, dependent: :destroy
  # Parties d'un plafond de forme complexe (rectangles additionnés).
  has_many :zones, -> { order(:position, :id) }, dependent: :destroy
  accepts_nested_attributes_for :deductions, allow_destroy: true

  # Type de support peint.
  KINDS = {
    "mur"     => "Mur",     # surface = longueur × hauteur
    "plafond" => "Plafond"  # surface = longueur × largeur
  }.freeze

  TYPES_CHANTIER = { "renovation" => "Rénovation", "neuf" => "Neuf" }.freeze

  # (kind, type_chantier) → clé de prestation Tarif (cohérent avec l'appli web).
  PRESTATION_MAP = {
    %w[mur renovation]     => "peinture_murs_reno",
    %w[mur neuf]           => "peinture_murs_neuf",
    %w[plafond renovation] => "peinture_plafond",
    %w[plafond neuf]       => "peinture_plafond_neuf"
  }.freeze

  # Préparations forfaitaires (ponçage / rebouchage) : catégorie + montant € par
  # défaut, ajustable sur site. Le forfait de la catégorie ne fait que pré-remplir
  # le champ ; l'artisan écrase le montant selon le chantier.
  PREP_CATEGORIES = {
    "aucun"     => { label: "Aucun",     forfait: 0   },
    "leger"     => { label: "Léger",     forfait: 20  },
    "moyen"     => { label: "Moyen",     forfait: 50  },
    "important" => { label: "Important", forfait: 100 }
  }.freeze

  validates :libelle, presence: true
  validates :kind, inclusion: { in: KINDS.keys }
  validates :type_chantier, inclusion: { in: TYPES_CHANTIER.keys }
  validates :gamme, inclusion: { in: Tarif::GAMMES.keys }
  validates :poncage_categorie,    inclusion: { in: PREP_CATEGORIES.keys }
  validates :rebouchage_categorie, inclusion: { in: PREP_CATEGORIES.keys }
  validates :ratissage_categorie,  inclusion: { in: PREP_CATEGORIES.keys }
  validates :longueur, :hauteur, :largeur, :prix_peinture_m2,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_save :recalculer

  def plafond?
    kind == "plafond"
  end

  def kind_label
    KINDS[kind] || kind
  end

  # Prestation Tarif correspondante (peinture_murs_reno, peinture_plafond_neuf…).
  def prestation
    PRESTATION_MAP[[kind, type_chantier]]
  end

  def prestation_label
    Tarif::PRESTATIONS.dig(prestation, :label) || prestation
  end

  def gamme_label
    Tarif::GAMMES.dig(gamme, :label) || gamme
  end

  def type_chantier_label
    TYPES_CHANTIER[type_chantier] || type_chantier
  end

  # Prix €/m² du barème (/admin/tarifs) pour cette prestation × gamme.
  def prix_tarif
    (Tarif.prix_for(prestation: prestation, gamme: gamme) || 0).to_d
  end

  # Surface brute avant déductions.
  # - mur     → longueur × hauteur
  # - plafond → somme des parties (rectangles) pour gérer les formes complexes ;
  #             repli sur longueur × largeur si aucune partie (ancien plafond).
  def surface_brute
    if plafond?
      parts = zones.reject(&:marked_for_destruction?)
      return parts.sum { |z| z.surface }.round(2) if parts.any?
      (longueur.to_d * largeur.to_d).round(2)
    else
      (longueur.to_d * hauteur.to_d).round(2)
    end
  end

  # Somme des ouvertures marquées "à déduire" (in-memory, gère le nested form).
  def surface_deduite
    deductions.reject(&:marked_for_destruction?).sum { |d| d.surface }.round(2)
  end

  # Surface réellement peinte (jamais négative).
  def surface_nette_calc
    [surface_brute - surface_deduite, 0.to_d].max.round(2)
  end

  # Total du mur = peinture au m² + forfaits prépa (ponçage, rebouchage, ratissage).
  def total_calc
    (surface_nette_calc * prix_peinture_m2.to_d +
     poncage_forfait.to_d + rebouchage_forfait.to_d + ratissage_forfait.to_d).round(2)
  end

  # Forfait par défaut d'une catégorie de prépa (pour pré-remplir le champ).
  def self.forfait_defaut(categorie)
    PREP_CATEGORIES.dig(categorie, :forfait).to_d
  end

  PREP_KINDS = %w[poncage rebouchage ratissage].freeze

  # La gamme inclut déjà la prépa standard : ces forfaits ne servent QUE pour
  # du surplus exceptionnel (mur anormalement abîmé). Vrai si au moins un est activé.
  def travaux_exceptionnels?
    PREP_KINDS.any? { |k| public_send("#{k}_categorie") != "aucun" }
  end

  # Somme des forfaits de travaux exceptionnels (au-delà de la gamme).
  def prep_total
    PREP_KINDS.sum { |k| public_send("#{k}_forfait").to_d }
  end

  # Part « peinture » seule (surface × prix gamme), hors travaux exceptionnels.
  def peinture_total
    (surface_nette.to_d * prix_peinture_m2.to_d).round(2)
  end

  private

  def recalculer
    self.surface_nette = surface_nette_calc
    self.total = total_calc
  end
end
