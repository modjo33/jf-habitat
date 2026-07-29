# Identité visuelle (DA) commune aux PDF de devis : logo, cartouche DEVIS sable,
# ligne épaisse orange, et ligne d'identité émetteur (SIRET, coordonnées) en pied
# de page — alimentée par les variables LEGAL_* (cohérent avec les mentions légales).
module DevisPdfBranding
  module_function

  INK      = [15, 42, 68]
  INK_SOFT = [74, 103, 133]
  ACCENT   = [230, 117, 42]
  SAND     = [250, 247, 242]

  LOGO_PATH = Rails.root.join("app/assets/images/logo.png").to_s

  def hexc(arr)
    arr.map { |n| n.to_s(16).rjust(2, "0") }.join.upcase
  end

  # Les blocs de totaux sont dessinés à coordonnées ABSOLUES dans une
  # `bounding_box` (bandeau plein + `text_box`). Prawn ne bascule pas de page
  # tout seul pour ce genre de tracé : quand le tableau des lignes descend trop
  # bas, le bandeau est dessiné SOUS le bas de page et disparaît — le document
  # sort sans montant total, et sans la moindre erreur pour le signaler.
  # Constaté sur un devis de 9 lignes ; vaut aussi pour les factures.
  #
  # À appeler avant d'ouvrir la bounding_box, avec la hauteur dont le bloc a
  # besoin (bandeau 30 + espacement 34 + mention 12, plus 14 par ligne de
  # détail affichée).
  HAUTEUR_BLOC_TOTAUX_BASE = 86
  HAUTEUR_LIGNE_DETAIL     = 14

  def reserver_place(pdf, lignes_detail: 0)
    necessaire = HAUTEUR_BLOC_TOTAUX_BASE + lignes_detail * HAUTEUR_LIGNE_DETAIL
    pdf.start_new_page if pdf.cursor < necessaire
  end

  # En-tête : logo (repli sur le nom si absent), cartouche DEVIS sable à droite,
  # puis une ligne épaisse orange (couleur du montant du total).
  def render_brand_header(pdf, titre:, reference:, date:)
    top = pdf.cursor
    if File.exist?(LOGO_PATH)
      pdf.image LOGO_PATH, at: [0, top], width: 168
      pdf.fill_color hexc(INK_SOFT); pdf.font_size 9
      pdf.text_box "Artisan peintre · plaquiste · parqueteur", at: [2, top - 62], width: 320
    else
      pdf.font_size 22; pdf.fill_color hexc(INK); pdf.text "JF Habitat", style: :bold
      pdf.font_size 10; pdf.fill_color hexc(INK_SOFT); pdf.text "Artisan peintre · plaquiste · parqueteur"
    end

    pdf.bounding_box([pdf.bounds.right - 210, top - 2], width: 210, height: 52) do
      pdf.fill_color hexc(SAND); pdf.fill_rectangle [0, 52], 210, 52
      pdf.fill_color hexc(INK);  pdf.text_box titre, at: [12, 42], size: 9, style: :bold
      pdf.text_box reference, at: [12, 28], size: 12, style: :bold
      pdf.fill_color hexc(INK_SOFT); pdf.text_box date, at: [12, 13], size: 9
    end

    pdf.move_cursor_to top - 76
    pdf.stroke_color hexc(ACCENT); pdf.line_width 2.5; pdf.stroke_horizontal_rule
    pdf.line_width 0.5
    pdf.move_down 16
  end

  # Ligne d'identité émetteur pour le pied de page (depuis LEGAL_*).
  def identity_line
    ok = ->(v) { v.present? && !v.include?("COMPLÉTER") }
    parts = []
    parts << (ok.(ENV["LEGAL_COMPANY_NAME"]) ? ENV["LEGAL_COMPANY_NAME"] : "JF Habitat")
    parts << "SIRET #{ENV['LEGAL_SIRET']}" if ok.(ENV["LEGAL_SIRET"])
    parts << ENV["LEGAL_PHONE"] if ok.(ENV["LEGAL_PHONE"])
    parts << (ENV["LEGAL_EMAIL"].presence || "contact@jfhabitat.fr")
    parts << "www.jfhabitat.fr"
    parts.join(" · ")
  end
end
