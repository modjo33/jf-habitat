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
    parts = []
    parts << (env_ok("LEGAL_COMPANY_NAME") ? ENV["LEGAL_COMPANY_NAME"] : "JF Habitat")
    parts << "SIRET #{ENV['LEGAL_SIRET']}" if env_ok("LEGAL_SIRET")
    parts << ENV["LEGAL_PHONE"] if env_ok("LEGAL_PHONE")
    parts << (ENV["LEGAL_EMAIL"].presence || "contact@jfhabitat.fr")
    parts << "www.jfhabitat.fr"
    parts.join(" · ")
  end

  # Mentions réglementaires du pied de page — obligatoires pour un artisan du
  # bâtiment : assurance décennale (art. 22-2 loi Hamon, devis ET factures) et
  # médiateur de la consommation. Fail-closed : variable absente → rien,
  # jamais de placeholder sur un document client.
  #   LEGAL_ASSURANCE_DECENNALE = "AXA France, contrat n° 123456, couverture France métropolitaine"
  #   LEGAL_MEDIATEUR           = "CNPM Médiation Consommation, 27 av. de la Libération 42400 Saint-Chamond, cnpm-mediation-consommation.eu"
  def mentions_reglementaires
    parts = []
    parts << "Assurance de responsabilité décennale : #{ENV['LEGAL_ASSURANCE_DECENNALE']}." if env_ok("LEGAL_ASSURANCE_DECENNALE")
    parts << "Médiateur de la consommation : #{ENV['LEGAL_MEDIATEUR']}." if env_ok("LEGAL_MEDIATEUR")
    parts
  end

  # Page « droit de rétractation » des devis : la signature se fait chez le
  # client (contrat hors établissement, Code conso L221) → l'information et le
  # formulaire détachable sont OBLIGATOIRES. Sans eux, le délai de 14 jours
  # devient 12 mois et le client peut annuler chantier fait.
  def render_retractation(pdf, reference:)
    pdf.start_new_page
    pdf.fill_color hexc(INK)
    pdf.font_size 13
    pdf.text "Droit de rétractation", style: :bold
    pdf.stroke_color hexc(ACCENT); pdf.line_width 2; pdf.stroke_horizontal_rule
    pdf.line_width 0.5
    pdf.move_down 12

    pdf.fill_color hexc(INK)
    pdf.font_size 9
    pdf.text "Lorsque ce devis est signé hors établissement (notamment au domicile du client), " \
             "le client dispose, conformément aux articles L221-18 et suivants du Code de la " \
             "consommation, d'un délai de quatorze (14) jours à compter de la signature pour " \
             "exercer son droit de rétractation, sans avoir à motiver sa décision ni supporter " \
             "de frais. Pour l'exercer, il adresse le formulaire ci-dessous — ou toute autre " \
             "déclaration dénuée d'ambiguïté — par courrier ou par e-mail avant l'expiration du délai.",
             leading: 2
    pdf.move_down 8
    pdf.text "Les travaux ne commencent pas avant l'expiration de ce délai, sauf demande expresse " \
             "du client formulée par écrit. En cas de rétractation après un début d'exécution " \
             "expressément demandé, le client règle le montant correspondant aux prestations " \
             "déjà réalisées.",
             leading: 2
    pdf.move_down 20

    # Formulaire détachable (ligne pointillée façon découpe).
    pdf.stroke_color hexc(INK_SOFT)
    pdf.dash(3, space: 3)
    pdf.stroke_horizontal_rule
    pdf.undash
    pdf.move_down 14

    destinataire = [
      env_ok("LEGAL_COMPANY_NAME") ? ENV["LEGAL_COMPANY_NAME"] : "JF Habitat",
      (ENV["LEGAL_ADDRESS"] if env_ok("LEGAL_ADDRESS")),
      ENV["LEGAL_EMAIL"].presence || "contact@jfhabitat.fr"
    ].compact.join(" — ")

    pdf.fill_color hexc(INK)
    pdf.font_size 10
    pdf.text "Formulaire de rétractation", style: :bold
    pdf.fill_color hexc(INK_SOFT)
    pdf.font_size 8
    pdf.text "(À compléter et renvoyer uniquement si vous souhaitez vous rétracter du contrat.)"
    pdf.move_down 10

    pdf.fill_color hexc(INK)
    pdf.font_size 9
    [
      "À l'attention de : #{destinataire}",
      "Je vous notifie par la présente ma rétractation du contrat portant sur la prestation " \
        "de travaux objet du devis n° #{reference}.",
      "Devis signé le : ............................................................",
      "Nom du client : .............................................................",
      "Adresse du client : .........................................................",
      "Date : ....................................    Signature : ...................................."
    ].each do |ligne|
      pdf.text ligne, leading: 3
      pdf.move_down 6
    end
  end

  def env_ok(key)
    v = ENV[key]
    v.present? && !v.include?("COMPLÉTER")
  end
end
