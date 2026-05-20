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

  # Prestations appliquées sur les MURS (déduction ouvertures applicable)
  MURS_PRESTATIONS = %w[peinture_murs_reno peinture_murs_neuf placo_cloison].freeze
  # Prestations appliquées sur PLAFOND ou SOL (surface = L × l)
  PLAFOND_SOL_PRESTATIONS = %w[peinture_plafond placo_plafond parquet_stratifie parquet_contrecolle parquet_massif].freeze

  # Surcharges options (% sur prix_m2)
  OPTIONS_SURCOUT = {
    rebouchage_lourd:     0.20,
    depose_ancien:        0.15,
    preparation_speciale: 0.25
  }.freeze

  # Déductions standard
  SURFACE_PORTE   = 2.0  # m² par porte
  SURFACE_FENETRE = 1.5  # m² par fenêtre

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

  def options_actives
    [].tap do |arr|
      arr << "Rebouchage lourd (+20%)"        if rebouchage_lourd
      arr << "Dépose ancien revêtement (+15%)" if depose_ancien
      arr << "Préparation spéciale (+25%)"     if preparation_speciale
    end
  end

  def prestation_sur_murs?
    MURS_PRESTATIONS.include?(prestation)
  end

  def prestation_sur_surface?
    PLAFOND_SOL_PRESTATIONS.include?(prestation)
  end

  # Calcul automatique de la surface à partir de L/l/H pour mode "dimensions"
  def surface_calculee_depuis_dimensions
    return nil unless mode_saisie == "dimensions"
    return nil if longueur.blank? || largeur.blank?

    if prestation_sur_murs?
      return nil if hauteur.blank?
      perimetre = 2 * (longueur.to_d + largeur.to_d)
      brute = perimetre * hauteur.to_d
      deduction = (nb_portes.to_i * SURFACE_PORTE) + (nb_fenetres.to_i * SURFACE_FENETRE)
      [(brute - deduction).round(2), 0].max
    else
      (longueur.to_d * largeur.to_d).round(2)
    end
  end

  def coef_options
    OPTIONS_SURCOUT.sum { |opt, val| send(opt) ? val : 0 }
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
    base = Tarif.prix_for(prestation: prestation, gamme: gamme) || 0
    # prix_m2 ajusté avec options (coef_type_piece et coefs globaux appliqués au niveau Estimation)
    self.prix_unitaire = (base.to_d * (1 + coef_options)).round(2)
  end

  def calculer_total
    return if surface.blank? || prix_unitaire.blank?
    # Total ligne = surface × prix_unitaire × coef_type_piece
    self.coef_applique = coef_type_piece
    self.total = (surface.to_d * prix_unitaire.to_d * coef_type_piece.to_d).round(2)
  end
end
