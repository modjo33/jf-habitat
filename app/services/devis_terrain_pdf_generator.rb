require "prawn"
require "prawn/table"

# PDF du devis établi sur place (outil tablette). Détail pièce → mur, franchise
# en base (pas de TVA), et bloc signature si le client a signé.
class DevisTerrainPdfGenerator
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
    render_pieces(pdf)
    render_totals(pdf)
    render_signature(pdf)
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
    pdf.font_size 22
    pdf.text "JF Habitat", style: :bold, color: hex(INK)
    pdf.font_size 10
    pdf.fill_color hex(INK_SOFT)
    pdf.text "Artisan peintre · plaquiste · parqueteur"

    pdf.move_down 20
    pdf.bounding_box([pdf.bounds.right - 200, pdf.cursor + 40], width: 200, height: 50) do
      pdf.fill_color hex(SAND)
      pdf.fill_rectangle [0, 50], 200, 50
      pdf.fill_color hex(INK)
      pdf.text_box "DEVIS", at: [10, 40], size: 9, style: :bold
      pdf.text_box @estimation.reference, at: [10, 26], size: 12, style: :bold
      pdf.text_box Time.current.strftime("%d/%m/%Y"), at: [10, 12], size: 9, color: hex(INK_SOFT)
    end

    pdf.stroke_color hex(INK)
    pdf.line_width 0.5
    pdf.stroke_horizontal_rule
    pdf.move_down 18
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

  def render_pieces(pdf)
    pdf.fill_color hex(INK)
    pdf.font_size 11
    pdf.text "DÉTAIL DES TRAVAUX", style: :bold
    pdf.move_down 8

    @estimation.pieces.includes(murs: :deductions).each do |piece|
      pdf.fill_color hex(INK)
      pdf.font_size 10
      pdf.text piece.nom, style: :bold
      pdf.move_down 2

      rows = [["Support", "Prestation", "Surface", "Prix/m²", "Total"]]
      piece.murs.each do |mur|
        rows << [
          mur.libelle,
          "#{mur.prestation_label}\n#{mur.gamme_label}",
          "#{fmt_num(mur.surface_nette)} m²",
          format_eur(mur.prix_peinture_m2),
          format_eur(mur.surface_nette.to_d * mur.prix_peinture_m2.to_d)
        ]
        if mur.prep_total.positive?
          rows << [{ content: "Travaux exceptionnels : #{exceptionnels_label(mur)}", colspan: 4, inline_format: true },
                   format_eur(mur.prep_total)]
        end
      end
      rows << [{ content: "Sous-total #{piece.nom}", colspan: 4, inline_format: true, font_style: :bold }, format_eur(piece.total)]

      pdf.font_size 8
      pdf.table(rows, width: pdf.bounds.width, header: true,
                column_widths: { 0 => 70, 2 => 60, 3 => 60, 4 => 70 }) do |t|
        t.row(0).background_color = to_hex(INK)
        t.row(0).text_color = "FFFFFF"
        t.row(0).font_style = :bold
        t.cells.padding = 5
        t.cells.borders = [:bottom]
        t.cells.border_color = "DDDDDD"
        t.cells.border_width = 0.3
        t.row(rows.size - 1).background_color = to_hex(SAND)
      end
      pdf.move_down 12
    end
  end

  def render_totals(pdf)
    pdf.bounding_box([pdf.bounds.right - 250, pdf.cursor], width: 250) do
      pdf.font_size 9
      pdf.fill_color hex(INK_SOFT)

      detail = @estimation.devis_remise_montant.to_d.positive? || @estimation.devis_extras_total.to_d.positive?
      if detail
        line(pdf, "Travaux de peinture", format_eur(@estimation.devis_total_brut))
      end
      if @estimation.devis_trajet_total.to_d.positive?
        jours = @estimation.devis_trajet_jours.to_d
        libelle = jours.positive? ? "Déplacement (#{fmt_num(jours).sub(/,0$/, '')} j)" : "Déplacement"
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

  def render_signature(pdf)
    return unless @estimation.devis_signe?

    pdf.move_down 6
    pdf.stroke_color "DDDDDD"
    pdf.stroke_horizontal_rule
    pdf.move_down 10
    pdf.fill_color hex(INK)
    pdf.font_size 10
    pdf.text "Bon pour accord", style: :bold
    pdf.fill_color hex(INK_SOFT)
    pdf.font_size 9
    pdf.text "Signé par #{@estimation.devis_signataire} le #{@estimation.devis_signe_at.strftime('%d/%m/%Y à %H:%M')}"

    begin
      png = @estimation.devis_signature.download
      pdf.move_down 6
      pdf.image StringIO.new(png), width: 180
    rescue => e
      Rails.logger.warn "[DevisPDF] signature non rendue : #{e.message}"
    end
  end

  def render_footer(pdf)
    pdf.move_cursor_to 60
    pdf.fill_color hex(INK_SOFT)
    pdf.font_size 7
    proof = @estimation.devis_signe? ? " · Signature électronique enregistrée (IP #{@estimation.devis_signature_ip})." : ""
    pdf.text "Devis établi sur place. Micro-entreprise, TVA non applicable (art. 293 B du CGI).#{proof}"
    pdf.move_down 6
    pdf.stroke_color "DDDDDD"
    pdf.stroke_horizontal_rule
    pdf.move_down 4
    pdf.text "JF Habitat — www.jfhabitat.fr", align: :center, size: 7
  end

  def exceptionnels_label(mur)
    Mur::PREP_KINDS.filter_map do |k|
      cat = mur.public_send("#{k}_categorie")
      "#{k.capitalize} (#{cat})" unless cat == "aucun"
    end.join(", ")
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

  def to_hex(arr)
    arr.map { |n| n.to_s(16).rjust(2, "0") }.join.upcase
  end
  alias hex to_hex
end
