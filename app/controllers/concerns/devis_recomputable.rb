# Recalcule le devis et renvoie les Turbo Streams qui rafraîchissent les
# totaux (barre globale + sous-total pièce + lecture mur), sans toucher aux
# champs de saisie (pour ne pas voler le focus pendant que l'artisan tape).
module DevisRecomputable
  extend ActiveSupport::Concern

  private

  def render_devis_totals(extra: [])
    @estimation.devis_recompute!
    @estimation.reload
    @piece&.reload
    @mur&.reload

    streams = [
      turbo_stream.replace("devis_total_bar",
        partial: "admin/devis/bar", locals: { estimation: @estimation })
    ]
    if @piece
      streams << turbo_stream.replace("piece_#{@piece.id}_readout",
        partial: "admin/devis/piece_readout", locals: { piece: @piece })
    end
    if @mur&.persisted?
      streams << turbo_stream.replace("mur_#{@mur.id}_readout",
        partial: "admin/devis/mur_readout", locals: { mur: @mur })
    end

    render turbo_stream: streams + Array(extra)
  end
end
