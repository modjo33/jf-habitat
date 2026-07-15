require "prawn"
require "prawn/table"

# PDF du devis « détaillé » construit depuis les lignes libres (Vague 1) :
# lignes groupées par section, avec description affichée sous chaque libellé,
# franchise en base (pas de TVA). Même DA que le devis terrain (DevisPdfBranding).
# Le rendu est stocké en base (DevisDocument), pas généré à la volée.
class DevisLignePdfGenerator
  INK      = [15, 42, 68]
  INK_SOFT = [74, 103, 133]
  ACCENT   = [230, 117, 42]
  SAND     = [250, 247, 242]

  def initialize(estimation)
    @estimation = estimation
  end

  def generate
    pdf = Prawn::Document.new(page_size: "A4", margin: [40, 40, 40, 40])
    setup_fonts(pdf)
    render_header(pdf)
    render_client_block(pdf)
    render_lignes(pdf)
    render_totals(pdf)
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
    DevisPdfBranding.render_brand_header(pdf, titre: "DEVIS",
      reference: @estimation.reference, date: Time.current.strftime("%d/%m/%Y"))
  end

  def render_client_block(pdf)
    pdf.fill_color hex(INK)
    pdf.font_size 11
    pdf.text "CLIENT", style: :bold
    pdf.move_down 4
    pdf.font_size 10
    pdf.fill_color hex(INK_SOFT)
    pdf.text @estimation.nom
    pdf.text @estimation.email if @estimation.email.present?
    pdf.text @estimation.telephone if @estimation.telephone.present?
    if @estimation.adresse.present?
      pdf.text @estimation.adresse
      pdf.text "#{@estimation.code_postal} #{@estimation.ville}".strip
    end
    pdf.move_down 16
  end

  def render_lignes(pdf)
    pdf.fill_color hex(INK)
    pdf.font_size 11
    pdf.text "DÉTAIL DES TRAVAUX", style: :bold
    pdf.move_down 8

    @estimation.devis_lignes.ordered.group_by(&:section).each do |section, lignes|
      pdf.fill_color hex(INK)
      pdf.font_size 10
      pdf.text section.presence || "Travaux", style: :bold
      pdf.move_down 2

      rows = [["Prestation", "Quantité", "Prix unit.", "Total"]]
      lignes.each { |l| rows << ligne_row(l) }
      sous_total = lignes.sum { |l| l.total.to_d }
      rows << [{ content: "Sous-total #{section.presence || 'Travaux'}", colspan: 3,
                 inline_format: true, font_style: :bold }, format_eur(sous_total)]

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
        t.row(rows.size - 1).background_color = hex(SAND)
        t.row(rows.size - 1).column(3).align = :right
      end
      pdf.move_down 12
    end
  end

  # Une ligne de tableau : libellé (gras) + description en plus petit dessous,
  # quantité×unité (ou « forfait »), prix unitaire, total.
  def ligne_row(ligne)
    prestation = "<b>#{escape(ligne.libelle)}</b>"
    if ligne.description.present?
      prestation += "\n<font size='7'>#{escape(ligne.description)}</font>"
    end
    qte = if ligne.forfait?
            "forfait"
          else
            "#{fmt_num(ligne.quantite)} #{ligne.unite_label}"
          end
    pu = ligne.forfait? ? "—" : format_eur(ligne.prix_unitaire)
    [{ content: prestation, inline_format: true }, qte, pu, format_eur(ligne.total)]
  end

  def render_totals(pdf)
    pdf.bounding_box([pdf.bounds.right - 250, pdf.cursor], width: 250) do
      pdf.font_size 9
      pdf.fill_color hex(INK_SOFT)

      detail = @estimation.devis_remise_montant.to_d.positive? || @estimation.devis_extras_total.to_d.positive?
      line(pdf, "Travaux", format_eur(@estimation.devis_total_brut)) if detail
      if @estimation.devis_trajet_total.to_d.positive?
        jours = @estimation.devis_trajet_jours.to_d
        libelle = jours.positive? ? "Déplacement (#{fmt_num(jours).sub(/,0+$/, '')} j)" : "Déplacement"
        line(pdf, libelle, format_eur(@estimation.devis_trajet_total))
      end
      if @estimation.devis_consommables.to_d.positive?
        lib = @estimation.devis_consommables_libelle.present? ? "Consommables (#{@estimation.devis_consommables_libelle})" : "Consommables"
        line(pdf, lib, format_eur(@estimation.devis_consommables))
      end
      if @estimation.devis_remise_montant.to_d.positive?
        line(pdf, "Sous-total", format_eur(@estimation.devis_sous_total))
        pdf.fill_color "2F9E44"
        line(pdf, "Remise", "- #{format_eur(@estimation.devis_remise_montant)}")
        pdf.fill_color hex(INK_SOFT)
      end
      if detail
        pdf.stroke_color "DDDDDD"
        pdf.stroke_horizontal_rule
        pdf.move_down 6
      end

      pdf.fill_color hex(INK)
      pdf.fill_rectangle [0, pdf.cursor + 2], 250, 30
      pdf.fill_color "FFFFFF"
      pdf.text_box "TOTAL", at: [12, pdf.cursor - 4], size: 10, style: :bold
      pdf.fill_color hex(ACCENT)
      pdf.text_box format_eur(@estimation.devis_total), at: [130, pdf.cursor - 2], size: 14, style: :bold, align: :right, width: 108
      pdf.move_down 34
      pdf.fill_color hex(INK_SOFT)
      pdf.text "TVA non applicable, art. 293 B du CGI", size: 8, align: :right
    end
    pdf.move_down 10
  end

  def render_footer(pdf)
    pdf.move_cursor_to 60
    pdf.fill_color hex(INK_SOFT)
    pdf.font_size 7
    pdf.text "Devis valable 3 mois. Micro-entreprise, TVA non applicable (art. 293 B du CGI)."
    pdf.move_down 6
    pdf.stroke_color "DDDDDD"
    pdf.stroke_horizontal_rule
    pdf.move_down 4
    pdf.text DevisPdfBranding.identity_line, align: :center, size: 7
  end

  def line(pdf, label, value, bold: false)
    pdf.text_box label, at: [0, pdf.cursor], width: 150, size: 9, style: (bold ? :bold : :normal)
    pdf.text_box value, at: [150, pdf.cursor], width: 90, size: 9, align: :right, style: (bold ? :bold : :normal)
    pdf.move_down 14
  end

  def format_eur(amount)
    "#{fmt_num(amount)} €"
  end

  def fmt_num(amount)
    format("%.2f", amount.to_f).gsub(".", ",")
  end

  # Échappe les entités pour l'inline_format de Prawn (libellés/descriptions saisis).
  def escape(str)
    str.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end

  def hex(arr)
    arr.map { |n| n.to_s(16).rjust(2, "0") }.join.upcase
  end
end
