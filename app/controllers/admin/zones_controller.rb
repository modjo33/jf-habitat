class Admin::ZonesController < Admin::BaseController
  include DevisRecomputable

  def create
    @mur = Mur.find(params[:mur_id])
    @piece = @mur.piece
    @estimation = @piece.estimation
    pos = @mur.zones.maximum(:position).to_i + 1
    @zone = @mur.zones.create!(libelle: "Partie #{pos + 1}", position: pos)

    render_devis_totals(extra: turbo_stream.append("mur_#{@mur.id}_zones",
      partial: "admin/devis/zone", locals: { zone: @zone }))
  end

  def update
    @zone = Zone.find(params[:id])
    @mur = @zone.mur
    @piece = @mur.piece
    @estimation = @piece.estimation
    @zone.update!(zone_params)
    # La surface de la ligne est recalculée côté client (voir autosave_controller)
    # pour ne pas déplacer le focus sur tablette ; on ne rafraîchit que les totaux.
    render_devis_totals
  end

  def destroy
    @zone = Zone.find(params[:id])
    @mur = @zone.mur
    @piece = @mur.piece
    @estimation = @piece.estimation
    id = @zone.id
    @zone.destroy
    render_devis_totals(extra: turbo_stream.remove("zone_#{id}"))
  end

  private

  def zone_params
    params.require(:zone).permit(:libelle, :longueur, :largeur)
  end
end
