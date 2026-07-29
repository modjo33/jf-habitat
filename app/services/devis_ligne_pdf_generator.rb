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
    render_conditions(pdf)
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
        # Serré volontairement : un devis d'une dizaine de lignes doit tenir sur
        # une page avec son total, sinon le montant part seul au verso.
        t.cells.padding = [3, 5, 3, 5]
        t.cells.borders = [:bottom]
        t.cells.border_color = "DDDDDD"
        t.cells.border_width = 0.3
        t.column(1).align = :center
        t.column(2).align = :right
        t.column(3).align = :right
        t.row(rows.size - 1).background_color = hex(SAND)
        t.row(rows.size - 1).column(3).align = :right
      end
      pdf.move_down 8
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
    # Sans cette réserve, le bandeau du total peut être tracé hors page.
    DevisPdfBranding.reserver_place(pdf, lignes_detail: nb_lignes_totaux)

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

  # Nombre de lignes de détail affichées au-dessus du bandeau TOTAL.
  def nb_lignes_totaux
    n = 0
    n += 1 if @estimation.devis_remise_montant.to_d.positive? || @estimation.devis_extras_total.to_d.positive?
    n += 1 if @estimation.devis_trajet_total.to_d.positive?
    n += 1 if @estimation.devis_consommables.to_d.positive?
    n += 2 if @estimation.devis_remise_montant.to_d.positive?
    n
  end

  # Conditions de paiement : échéancier (versements %) OU acompte + solde
  # (ancien modèle), suivi des modalités libres.
  def render_conditions(pdf)
    echeances = @estimation.devis_echeances_list
    acompte   = @estimation.devis_acompte_montant.to_d.positive?
    texte     = @estimation.devis_conditions.to_s.strip
    return if echeances.empty? && !acompte && texte.blank?

    # Le bloc doit rester d'un seul tenant : un solde isolé au verso, sous un
    # acompte resté page précédente, se lit mal et fait douter du montant.
    hauteur = 34 + 14 * [echeances.size, acompte ? 2 : 0].max + 12 * texte.lines.size
    pdf.start_new_page if pdf.cursor < hauteur

    pdf.move_down 6
    pdf.fill_color hex(INK)
    pdf.font_size 10
    pdf.text "CONDITIONS DE PAIEMENT", style: :bold
    pdf.move_down 4
    pdf.fill_color hex(INK_SOFT)
    pdf.font_size 9
    if echeances.any?
      echeances.each do |e|
        libelle = e[:pct] ? "#{e[:libelle]} (#{fmt_pct(e[:pct])} %)" : e[:libelle]
        pdf.text "#{libelle} : #{format_eur(e[:montant])}"
      end
    elsif acompte
      pdf.text "Acompte à la commande (#{@estimation.devis_acompte_pct.to_i} %) : "\
               "#{format_eur(@estimation.devis_acompte_montant)}"
      pdf.text "Solde à la fin des travaux : #{format_eur(@estimation.devis_solde_montant)}"
    end
    if texte.present?
      pdf.move_down 2
      texte.each_line { |l| pdf.text l.strip } # respecte les retours à la ligne saisis
    end
    pdf.move_down 8
  end

  # Bloc « Bon pour accord » + image de la signature horodatée (si signé).
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
      Rails.logger.warn "[DevisLignePDF] signature non rendue : #{e.message}"
    end
  end

  def render_footer(pdf)
    pdf.move_cursor_to 60
    pdf.fill_color hex(INK_SOFT)
    pdf.font_size 7
    proof = @estimation.devis_signe? ? " · Signature électronique enregistrée (IP #{@estimation.devis_signature_ip})." : ""
    pdf.text "Devis valable 3 mois. Micro-entreprise, TVA non applicable (art. 293 B du CGI).#{proof}"
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

  # Pourcentage sans décimale superflue : 30 → "30", 12.5 → "12,5".
  def fmt_pct(pct)
    d = pct.to_d
    (d == d.to_i ? d.to_i : d.to_f).to_s.gsub(".", ",")
  end

  # Échappe les entités pour l'inline_format de Prawn (libellés/descriptions saisis).
  def escape(str)
    str.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end

  def hex(arr)
    arr.map { |n| n.to_s(16).rjust(2, "0") }.join.upcase
  end
end
