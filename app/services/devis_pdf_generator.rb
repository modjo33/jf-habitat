require "prawn"
require "prawn/table"

class DevisPdfGenerator
  INK       = [15, 42, 68]
  INK_SOFT  = [74, 103, 133]
  ACCENT    = [230, 117, 42]
  SAND      = [250, 247, 242]

  def initialize(estimation)
    @estimation = estimation
  end

  def generate
    pdf = Prawn::Document.new(page_size: "A4", margin: [40, 40, 40, 40])
    setup_fonts(pdf)
    render_header(pdf)
    render_client_block(pdf)
    render_lines_table(pdf)
    render_totals(pdf)
    render_footer(pdf)
    pdf
  end

  def setup_fonts(pdf)
    font_dir = self.class.resolve_font_dir
    return unless font_dir
    pdf.font_families.update(
      "DejaVu" => {
        normal: File.join(font_dir, "DejaVuSans.ttf"),
        bold:   File.join(font_dir, "DejaVuSans-Bold.ttf")
      }
    )
    pdf.font "DejaVu"
  end

  def self.resolve_font_dir
    %w[
      /usr/share/fonts/truetype/dejavu
      /Library/Fonts
      /usr/share/fonts/TTF
    ].find { |d| File.exist?(File.join(d, "DejaVuSans.ttf")) }
  end

  private

  def render_header(pdf)
    pdf.fill_color rgb(INK)
    pdf.font_size 22
    pdf.text "JF Habitat", style: :bold, color: hex(INK)
    pdf.font_size 10
    pdf.fill_color rgb(INK_SOFT)
    pdf.text "Artisan peintre · plaquiste · parqueteur"

    # Bandeau réf + date
    pdf.move_down 20
    pdf.bounding_box([pdf.bounds.right - 200, pdf.cursor + 40], width: 200, height: 50) do
      pdf.fill_color rgb(SAND)
      pdf.fill_rectangle [0, 50], 200, 50
      pdf.fill_color rgb(INK)
      pdf.text_box "DEVIS ESTIMATIF", at: [10, 40], size: 9, style: :bold
      pdf.text_box @estimation.reference, at: [10, 26], size: 12, style: :bold
      pdf.text_box @estimation.created_at.strftime("%d/%m/%Y"), at: [10, 12], size: 9, color: hex(INK_SOFT)
    end

    pdf.stroke_color hex(INK)
    pdf.line_width 0.5
    pdf.stroke_horizontal_rule
    pdf.move_down 20
  end

  def render_client_block(pdf)
    pdf.fill_color rgb(INK)
    pdf.font_size 11
    pdf.text "CLIENT", style: :bold
    pdf.move_down 4
    pdf.font_size 10
    pdf.fill_color rgb(INK_SOFT)
    pdf.text @estimation.nom
    pdf.text @estimation.email
    pdf.text @estimation.telephone
    if @estimation.adresse.present?
      pdf.text @estimation.adresse
      pdf.text "#{@estimation.code_postal} #{@estimation.ville}".strip
    end
    pdf.move_down 6
    pdf.text "Chantier : #{@estimation.type_chantier_label} · Délai : #{@estimation.delai_label}", size: 9
    pdf.move_down 16
  end

  def render_lines_table(pdf)
    pdf.fill_color rgb(INK)
    pdf.font_size 11
    pdf.text "DÉTAIL DES PRESTATIONS", style: :bold
    pdf.move_down 8

    headers = [["Pièce", "Prestation", "Gamme", "Surface", "Prix/m²", "Total HT"]]
    rows = @estimation.estimation_lines.map do |l|
      [
        { content: "#{l.piece}\n#{l.type_piece_label}", inline_format: true },
        { content: "#{l.prestation_label}#{l.options_actives.any? ? "\n+ #{l.options_actives.join(', ')}" : ''}", inline_format: true },
        l.gamme_label,
        "#{l.surface} m²",
        format_eur(l.prix_unitaire),
        format_eur(l.total)
      ]
    end

    pdf.font_size 8
    pdf.table(headers + rows, width: pdf.bounds.width, header: true,
              column_widths: { 0 => 90, 2 => 70, 3 => 55, 4 => 65, 5 => 70 }) do |t|
      t.row(0).background_color = to_hex(INK)
      t.row(0).text_color = "FFFFFF"
      t.row(0).font_style = :bold
      t.row(0).size = 8
      t.cells.padding = 6
      t.cells.borders = [:bottom]
      t.cells.border_color = "DDDDDD"
      t.cells.border_width = 0.3
      (1..rows.size).each_with_index do |r|
        t.row(r).background_color = r.odd? ? "FFFFFF" : to_hex(SAND)
      end
    end

    pdf.move_down 12
  end

  def render_totals(pdf)
    sous_total = @estimation.estimation_lines.sum(&:total)
    tva_euros = @estimation.total_ttc - @estimation.total_ht

    pdf.bounding_box([pdf.bounds.right - 250, pdf.cursor], width: 250) do
      pdf.font_size 9
      pdf.fill_color rgb(INK_SOFT)

      line(pdf, "Sous-total prestations", format_eur(sous_total))
      if @estimation.coef_region.to_d != 1.0
        line(pdf, @estimation.coef_region_label, "× #{@estimation.coef_region}")
      end
      if @estimation.coef_etage.to_d != 1.0
        line(pdf, @estimation.coef_etage_label, "× #{@estimation.coef_etage}")
      end

      pdf.stroke_color "DDDDDD"
      pdf.stroke_horizontal_rule
      pdf.move_down 6

      pdf.fill_color rgb(INK)
      line(pdf, "Total HT", format_eur(@estimation.total_ht), bold: true)
      line(pdf, "TVA #{@estimation.tva_taux}%", format_eur(tva_euros))

      pdf.fill_color rgb(INK)
      pdf.fill_rectangle [0, pdf.cursor + 2], 250, 32
      pdf.fill_color "FFFFFF"
      pdf.text_box "Total TTC", at: [12, pdf.cursor - 4], size: 10, style: :bold
      pdf.fill_color rgb(ACCENT)
      pdf.text_box format_eur(@estimation.total_ttc), at: [140, pdf.cursor - 2], size: 14, style: :bold, align: :right, width: 100
      pdf.move_down 40
    end
  end

  def render_footer(pdf)
    pdf.move_cursor_to 80
    pdf.fill_color rgb(INK_SOFT)
    pdf.font_size 7
    pdf.text "⚠ Estimation indicative établie automatiquement à partir des informations fournies. Le devis définitif " \
             "sera établi après visite sur place pour tenir compte des spécificités de votre chantier " \
             "(état des supports, accessibilité, finitions particulières). Ce document n'a pas valeur d'engagement contractuel."
    pdf.move_down 8
    pdf.stroke_color "DDDDDD"
    pdf.stroke_horizontal_rule
    pdf.move_down 4
    pdf.text "JF Habitat — www.jfhabitat.fr", align: :center, size: 7
  end

  def line(pdf, label, value, bold: false)
    pdf.text_box label, at: [0, pdf.cursor], width: 140, size: 9, style: (bold ? :bold : :normal)
    pdf.text_box value, at: [140, pdf.cursor], width: 100, size: 9, align: :right, style: (bold ? :bold : :normal)
    pdf.move_down 14
  end

  def format_eur(amount)
    "#{format('%.2f', amount.to_f).gsub('.', ',')} €"
  end

  def rgb(arr)
    to_hex(arr)
  end

  def to_hex(arr)
    arr.map { |n| n.to_s(16).rjust(2, "0") }.join.upcase
  end

  def hex(arr)
    to_hex(arr)
  end
end
