require "prawn"
require "prawn/table"

# PDF de facture — même DA que les devis (DevisPdfBranding), avec en plus le
# bloc règlement : total, acompte(s) déjà encaissé(s), solde à régler.
# Franchise en base : aucune TVA. Rendu stocké en base (Facture#pdf_data).
class FacturePdfGenerator
  INK      = [15, 42, 68]
  INK_SOFT = [74, 103, 133]
  ACCENT   = [230, 117, 42]
  SAND     = [250, 247, 242]
  VERT     = [30, 122, 70]

  def initialize(facture)
    @facture = facture
  end

  def generate
    pdf = Prawn::Document.new(page_size: "A4", margin: [40, 40, 40, 40])
    setup_fonts(pdf)
    render_header(pdf)
    render_client_block(pdf)
    render_lignes(pdf)
    render_totals(pdf)
    render_conditions(pdf)
    render_footer(pdf)
    pdf
  end

  def setup_fonts(pdf)
    font_dir = DevisPdfGenerator.resolve_font_dir
    return unless font_dir
    pdf.font_families.update(
      "DejaVu" => {
        normal: File.join(font_dir, "DejaVuSans.ttf"),
        bold:   File.join(font_dir, "DejaVuSans-Bold.ttf")
      }
    )
    pdf.font "DejaVu"
  end

  private

  def render_header(pdf)
    DevisPdfBranding.render_brand_header(pdf, titre: "FACTURE",
      reference: @facture.numero, date: @facture.date_emission.strftime("%d/%m/%Y"))

    # Pastille d'état (payée / acompte reçu / à régler), sous le cartouche.
    couleur = @facture.payee? ? VERT : ACCENT
    libelle = @facture.etat_reglement.upcase
    y = pdf.cursor
    pdf.fill_color hex(couleur)
    pdf.fill_rectangle [pdf.bounds.right - 210, y], 130, 16
    pdf.fill_color "FFFFFF"
    pdf.text_box libelle, at: [pdf.bounds.right - 202, y - 4], size: 8, style: :bold
    pdf.fill_color hex(INK)
    pdf.move_down 12
  end

  def render_client_block(pdf)
    c = @facture.client
    pdf.fill_color hex(INK)
    pdf.font_size 11
    pdf.text "CLIENT", style: :bold
    pdf.move_down 4
    pdf.font_size 10
    pdf.fill_color hex(INK_SOFT)
    pdf.text c.nom.to_s.strip
    pdf.text c.adresse if c.adresse.present?
    pdf.text "#{c.code_postal} #{c.ville}".strip if c.code_postal.present? || c.ville.present?
    if @facture.chantier_adresse.present? || @facture.objet.present?
      pdf.move_down 6
      pdf.font_size 8
      detail = ["Chantier : #{@facture.chantier_adresse}".strip, @facture.objet].reject(&:blank?)
      pdf.text detail.join(" · ")
    end
    pdf.move_down 16
  end

  def render_lignes(pdf)
    pdf.fill_color hex(INK)
    pdf.font_size 11
    pdf.text "DÉTAIL DES PRESTATIONS", style: :bold
    pdf.move_down 8

    @facture.facture_lignes.ordered.group_by { |l| l.section.presence }.each do |section, lignes|
      if section.present?
        pdf.fill_color hex(INK)
        pdf.font_size 10
        pdf.text section, style: :bold
        pdf.move_down 2
      end

      rows = [["Désignation", "Quantité", "Prix unit.", "Total"]]
      lignes.each { |l| rows << ligne_row(l) }

      pdf.font_size 8
      pdf.table(rows, width: pdf.bounds.width, header: true,
                column_widths: { 1 => 80, 2 => 75, 3 => 75 }) do |t|
        t.row(0).background_color = hex(INK)
        t.row(0).text_color = "FFFFFF"
        t.row(0).font_style = :bold
        t.cells.padding = 5
        t.cells.borders = [:bottom]
        t.cells.border_color = "DDDDDD"
        t.cells.border_width = 0.3
        t.column(1).align = :center
        t.column(2).align = :right
        t.column(3).align = :right
      end
      pdf.move_down 12
    end
  end

  def ligne_row(ligne)
    designation = "<b>#{escape(ligne.libelle)}</b>"
    if ligne.description.present?
      designation += "\n<font size='7'>#{escape(ligne.description)}</font>"
    end
    qte = ligne.forfait? ? "forfait" : "#{fmt_num(ligne.quantite)} #{ligne.unite_label}"
    pu  = ligne.forfait? ? "—" : format_eur(ligne.prix_unitaire)
    [{ content: designation, inline_format: true }, qte, pu, format_eur(ligne.total)]
  end

  # Total → acompte(s) encaissé(s) → solde à régler (bandeau marine/orange).
  def render_totals(pdf)
    pdf.bounding_box([pdf.bounds.right - 250, pdf.cursor], width: 250) do
      pdf.font_size 9
      pdf.fill_color hex(INK_SOFT)
      line(pdf, "Total", format_eur(@facture.total), bold: true)
      line(pdf, "TVA non applicable, art. 293 B du CGI", "—")

      encaisse = @facture.montant_encaisse
      if encaisse.positive?
        pdf.fill_color hex(VERT)
        libelle = @facture.payee? ? "Réglé" : "Acompte déjà versé"
        line(pdf, libelle, "- #{format_eur(encaisse)}", bold: true)
        pdf.fill_color hex(INK_SOFT)
      end

      pdf.fill_color hex(INK)
      pdf.fill_rectangle [0, pdf.cursor + 2], 250, 30
      pdf.fill_color "FFFFFF"
      pdf.text_box(@facture.payee? ? "PAYÉE" : "SOLDE À RÉGLER",
                   at: [12, pdf.cursor - 4], size: 10, style: :bold)
      pdf.fill_color hex(ACCENT)
      pdf.text_box format_eur(@facture.payee? ? @facture.total : @facture.solde),
                   at: [130, pdf.cursor - 2], size: 14, style: :bold, align: :right, width: 108
      pdf.move_down 34
    end
    pdf.move_down 10
  end

  def render_conditions(pdf)
    pdf.move_down 6
    pdf.fill_color hex(INK)
    pdf.font_size 10
    pdf.text "CONDITIONS DE RÈGLEMENT", style: :bold
    pdf.move_down 4
    pdf.fill_color hex(INK_SOFT)
    pdf.font_size 8
    if @facture.conditions.present?
      @facture.conditions.each_line { |l| pdf.text l.strip }
      pdf.move_down 4
    end
    pdf.text @facture.payee? ? "Facture acquittée." : "Solde payable à réception de la facture."
    pdf.text "TVA non applicable, article 293 B du CGI (franchise en base)."
    pdf.text "Aucun escompte accordé pour paiement anticipé."
    pdf.text "Pénalités de retard : trois fois le taux d'intérêt légal en vigueur."
    pdf.text "Indemnité forfaitaire pour frais de recouvrement en cas de retard : 40 €."

    if @facture.encaissements.any?
      pdf.move_down 6
      pdf.fill_color hex(INK)
      pdf.text "RÈGLEMENTS REÇUS", style: :bold, size: 9
      pdf.fill_color hex(INK_SOFT)
      @facture.encaissements.chronologique.each do |e|
        pdf.text "#{e.date_encaissement.strftime('%d/%m/%Y')} — #{e.mode_reglement_label} : #{format_eur(e.montant)}"
      end
    end
    pdf.move_down 8
  end

  def render_footer(pdf)
    pdf.move_cursor_to 50
    pdf.fill_color hex(INK_SOFT)
    pdf.font_size 7
    pdf.stroke_color "DDDDDD"
    pdf.stroke_horizontal_rule
    pdf.move_down 4
    pdf.text DevisPdfBranding.identity_line, align: :center, size: 7
  end

  def line(pdf, label, value, bold: false)
    pdf.text_box label, at: [0, pdf.cursor], width: 150, size: (label.length > 30 ? 7 : 9),
                        style: (bold ? :bold : :normal)
    pdf.text_box value, at: [150, pdf.cursor], width: 90, size: 9, align: :right,
                        style: (bold ? :bold : :normal)
    pdf.move_down 14
  end

  def format_eur(amount) = "#{fmt_num(amount)} €"
  def fmt_num(amount)    = format("%.2f", amount.to_f).gsub(".", ",")

  def escape(str)
    str.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end

  def hex(arr) = arr.map { |n| n.to_s(16).rjust(2, "0") }.join.upcase
end
