class EstimationCalculatorService
  def self.preview(lines_params, context: {})
    new(lines_params, context: context).preview
  end

  def initialize(lines_params, context: {})
    @lines_params = Array(lines_params)
    @context = context.to_h.with_indifferent_access
  end

  def preview
    lines = @lines_params.map { |p| build_preview_line(p) }.compact
    surface_totale = lines.sum { |l| l[:surface] }
    sous_total = lines.sum { |l| l[:total] }

    # Coefficients globaux
    coef_region = calculer_coef_region
    coef_etage  = calculer_coef_etage

    apres_coefs = sous_total * coef_region * coef_etage

    tva = 10.0
    total_ttc = (apres_coefs * (1 + tva / 100)).round(2)

    {
      lines: lines,
      surface_totale: surface_totale.round(2),
      sous_total: sous_total.round(2),
      coef_region: coef_region,
      coef_region_label: label_coef_region(coef_region),
      coef_etage: coef_etage,
      coef_etage_label: label_coef_etage(coef_etage),
      total_ht: apres_coefs.round(2),
      total_ttc: total_ttc,
      tva_taux: tva,
      count: lines.size
    }
  end

  private

  def build_preview_line(params)
    prestation = params["prestation"]
    return nil if prestation.blank?

    mode = params["mode_saisie"].presence || "surface"
    surface = calc_surface(params, mode, prestation)
    return nil if surface.to_f <= 0

    gamme = params["gamme"].presence || "milieu"
    type_piece = params["type_piece"].presence || "autre"
    base_prix = Tarif.prix_for(prestation: prestation, gamme: gamme) || 0

    coef_piece = EstimationLine::TYPES_PIECE.dig(type_piece, :coef) || 1.0
    prix_unit = base_prix.to_d.round(2)
    total = (surface.to_d * prix_unit * coef_piece).round(2)

    {
      piece: params["piece"].presence || "Pièce",
      type_piece: type_piece,
      type_piece_label: EstimationLine::TYPES_PIECE.dig(type_piece, :label),
      prestation: prestation,
      prestation_label: Tarif::PRESTATIONS.dig(prestation, :label),
      gamme: gamme,
      gamme_label: Tarif::GAMMES.dig(gamme, :label),
      surface: surface.to_f.round(2),
      mode_saisie: mode,
      prix_unitaire: prix_unit.to_f,
      coef_piece: coef_piece,
      total: total.to_f,
      options: []
    }
  end

  # mode "dimensions" : murs → longueur × hauteur ; sols/plafonds → longueur × largeur
  def calc_surface(params, mode, prestation)
    return params["surface"].to_f unless mode == "dimensions"

    l = params["longueur"].to_f
    if EstimationLine::MURS_PRESTATIONS.include?(prestation)
      h = params["hauteur"].to_f
      return 0 if l <= 0 || h <= 0
      l * h
    else
      w = params["largeur"].to_f
      return 0 if l <= 0 || w <= 0
      l * w
    end
  end

  def truthy?(val)
    %w[1 true on yes].include?(val.to_s)
  end

  def calculer_coef_region
    cp = @context[:code_postal]
    return 1.0 if cp.blank?
    dept = cp.to_s.strip[0, 2]
    zone = Estimation::COEFFICIENTS_REGION.values.find { |z| z[:cp].include?(dept) }
    zone ? zone[:coef].to_f : 1.0
  end

  def calculer_coef_etage
    etage = @context[:etage].to_i
    return 1.0 if etage <= 2
    truthy?(@context[:ascenseur]) ? 1.03 : 1.10
  end

  def label_coef_region(coef)
    return nil if coef == 1.0
    pct = ((coef - 1) * 100).to_i
    zone = Estimation::COEFFICIENTS_REGION.values.find { |z| z[:coef].to_f == coef }
    zone ? "#{zone[:label]} +#{pct}%" : "Zone +#{pct}%"
  end

  def label_coef_etage(coef)
    return nil if coef == 1.0
    pct = ((coef - 1) * 100).to_i
    "Étage élevé +#{pct}%"
  end
end
