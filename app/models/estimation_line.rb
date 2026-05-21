class EstimationLine < ApplicationRecord
  belongs_to :estimation

  TYPES_PIECE = {
    "salon"         => { label: "Salon / Séjour",       coef: 1.0  },
    "chambre"       => { label: "Chambre",              coef: 1.0  },
    "cuisine"       => { label: "Cuisine",              coef: 1.15 },
    "salle_de_bain" => { label: "Salle de bain / WC",   coef: 1.15 },
    "couloir"       => { label: "Couloir / Entrée",     coef: 1.05 },
    "bureau"        => { label: "Bureau",               coef: 1.0  },
    "autre"         => { label: "Autre",                coef: 1.0  }
  }.freeze

  MODES_SAISIE = %w[surface dimensions].freeze

  # Prestations appliquées sur les MURS → surface = longueur (de mur) × hauteur
  MURS_PRESTATIONS = %w[peinture_murs_reno peinture_murs_neuf placo_cloison].freeze
  # Prestations appliquées sur PLAFOND ou SOL → surface = longueur × largeur
  PLAFOND_SOL_PRESTATIONS = %w[peinture_plafond placo_plafond parquet_stratifie parquet_contrecolle parquet_massif].freeze

  validates :piece, presence: true
  validates :prestation, presence: true, inclusion: { in: Tarif::PRESTATIONS.keys }
  validates :gamme, presence: true, inclusion: { in: Tarif::GAMMES.keys }
  validates :type_piece, inclusion: { in: TYPES_PIECE.keys }
  validates :mode_saisie, inclusion: { in: MODES_SAISIE }
  validates :surface, presence: true, numericality: { greater_than: 0, less_than: 10_000 }
  validates :prix_unitaire, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_validation :calculer_surface_depuis_dimensions
  before_validation :calculer_prix, :calculer_total

  def prestation_label
    Tarif::PRESTATIONS.dig(prestation, :label) || prestation
  end

  def gamme_label
    Tarif::GAMMES.dig(gamme, :label) || gamme
  end

  def type_piece_label
    TYPES_PIECE.dig(type_piece, :label) || type_piece
  end

  def prestation_sur_murs?
    MURS_PRESTATIONS.include?(prestation)
  end

  def prestation_sur_surface?
    PLAFOND_SOL_PRESTATIONS.include?(prestation)
  end

  # Calcul de la surface en mode "dimensions" :
  # - murs        → longueur (de mur) × hauteur
  # - sols/plafonds → longueur × largeur
  def surface_calculee_depuis_dimensions
    return nil unless mode_saisie == "dimensions"

    if prestation_sur_murs?
      return nil if longueur.blank? || hauteur.blank?
      (longueur.to_d * hauteur.to_d).round(2)
    else
      return nil if longueur.blank? || largeur.blank?
      (longueur.to_d * largeur.to_d).round(2)
    end
  end

  def coef_type_piece
    TYPES_PIECE.dig(type_piece, :coef) || 1.0
  end

  private

  def calculer_surface_depuis_dimensions
    return unless mode_saisie == "dimensions"
    s = surface_calculee_depuis_dimensions
    self.surface = s if s
  end

  def calculer_prix
    return if prestation.blank? || gamme.blank?
    self.prix_unitaire = (Tarif.prix_for(prestation: prestation, gamme: gamme) || 0).to_d.round(2)
  end

  def calculer_total
    return if surface.blank? || prix_unitaire.blank?
    # Total ligne = surface × prix_unitaire × coef_type_piece
    self.coef_applique = coef_type_piece
    self.total = (surface.to_d * prix_unitaire.to_d * coef_type_piece.to_d).round(2)
  end
end
