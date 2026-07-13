module RdvsHelper
  # Convertit un hex (#RRGGBB) en rgba(...) — compatible partout (dont iPad Safari).
  def hex_rgba(hex, alpha)
    h = hex.to_s.delete("#")
    r = h[0, 2].to_i(16); g = h[2, 2].to_i(16); b = h[4, 2].to_i(16)
    "rgba(#{r}, #{g}, #{b}, #{alpha})"
  end

  # Style de fond d'une case de calendrier selon les RDV du jour :
  # 1 type → teinte unie ; plusieurs → dégradé segmenté (une bande par couleur).
  def rdv_cell_style(rdvs, alpha: 0.20)
    colors = Array(rdvs).reject { |r| r.statut == "annule" }.map(&:couleur).uniq
    return "" if colors.empty?

    if colors.size == 1
      "background:#{hex_rgba(colors.first, alpha)};"
    else
      seg = 100.0 / colors.size
      stops = colors.each_with_index.map do |c, i|
        rgba = hex_rgba(c, alpha)
        "#{rgba} #{(i * seg).round}%, #{rgba} #{((i + 1) * seg).round}%"
      end.join(", ")
      "background:linear-gradient(135deg, #{stops});"
    end
  end
end
