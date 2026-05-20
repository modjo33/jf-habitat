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
    remise = calculer_remise_degressive(surface_totale)

    apres_coefs = sous_total * coef_region * coef_etage
    apres_remise = apres_coefs * (1 - remise)

    tva = 10.0
    total_ttc = (apres_remise * (1 + tva / 100)).round(2)

    {
      lines: lines,
      surface_totale: surface_totale.round(2),
      sous_total: sous_total.round(2),
      coef_region: coef_region,
      coef_region_label: label_coef_region(coef_region),
      coef_etage: coef_etage,
      coef_etage_label: label_coef_etage(coef_etage),
      remise_degressive: remise,
      remise_euros: (apres_coefs - apres_remise).round(2),
      total_ht: apres_remise.round(2),
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

    # Options
    coef_options = 0
    coef_options += 0.20 if truthy?(params["rebouchage_lourd"])
    coef_options += 0.15 if truthy?(params["depose_ancien"])
    coef_options += 0.25 if truthy?(params["preparation_speciale"])

    # Coef pièce
    coef_piece = EstimationLine::TYPES_PIECE.dig(type_piece, :coef) || 1.0

    prix_unit = (base_prix.to_d * (1 + coef_options)).round(2)
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
      options: options_actives(params)
    }
  end

  def calc_surface(params, mode, prestation)
    if mode == "dimensions"
      l = params["longueur"].to_f
      w = params["largeur"].to_f
      return 0 if l <= 0 || w <= 0

      if EstimationLine::MURS_PRESTATIONS.include?(prestation)
        h = params["hauteur"].to_f
        return 0 if h <= 0
        perimetre = 2 * (l + w)
        brute = perimetre * h
        deduction = params["nb_portes"].to_i * EstimationLine::SURFACE_PORTE + params["nb_fenetres"].to_i * EstimationLine::SURFACE_FENETRE
        [brute - deduction, 0].max
      else
        l * w
      end
    else
      params["surface"].to_f
    end
  end

  def options_actives(params)
    [].tap do |arr|
      arr << "Rebouchage lourd"  if truthy?(params["rebouchage_lourd"])
      arr << "Dépose ancien"     if truthy?(params["depose_ancien"])
      arr << "Préparation spé."  if truthy?(params["preparation_speciale"])
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

  def calculer_remise_degressive(surface)
    Estimation::SEUILS_REMISE.detect { |s| surface >= s[:seuil_m2] }&.dig(:remise).to_f
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
