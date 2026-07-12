class Admin::MursController < Admin::BaseController
  include DevisRecomputable

  def create
    @piece = Piece.find(params[:piece_id])
    @estimation = @piece.estimation
    kind = params[:kind] == "plafond" ? "plafond" : "mur"
    pos = @piece.murs.maximum(:position).to_i + 1
    libelle = kind == "plafond" ? "Plafond" : "Mur #{@piece.murs.where(kind: "mur").count + 1}"

    @mur = @piece.murs.new(
      libelle: libelle, kind: kind, position: pos,
      type_chantier: @estimation.type_chantier.presence || "renovation",
      gamme: @estimation.estimation_lines.map(&:gamme).compact.first || "milieu",
      hauteur: kind == "mur" ? @piece.hauteur_sous_plafond : 0
    )
    @mur.prix_peinture_m2 = @mur.prix_tarif   # pré-rempli depuis /admin/tarifs
    @mur.save!
    # Un plafond démarre avec une première partie (rectangle) à mesurer.
    @mur.zones.create!(libelle: "Partie 1", position: 0) if @mur.plafond?
    @estimation.devis_recompute!
    @estimation.reload
    @piece.reload
    render turbo_stream: [
      turbo_stream.append("piece_#{@piece.id}_murs", partial: "admin/devis/mur", locals: { mur: @mur }),
      turbo_stream.replace("piece_#{@piece.id}_readout", partial: "admin/devis/piece_readout", locals: { piece: @piece }),
      turbo_stream.replace("devis_total_bar", partial: "admin/devis/bar", locals: { estimation: @estimation })
    ]
  end

  def update
    @mur = Mur.find(params[:id])
    @piece = @mur.piece
    @estimation = @piece.estimation
    @mur.update!(mur_params)
    render_devis_totals
  end

  def destroy
    @mur = Mur.find(params[:id])
    @piece = @mur.piece
    @estimation = @piece.estimation
    id = @mur.id
    @mur.destroy
    @mur = nil
    render_devis_totals(extra: turbo_stream.remove("mur_#{id}"))
  end

  private

  def mur_params
    params.require(:mur).permit(:libelle, :kind, :type_chantier, :gamme,
      :longueur, :hauteur, :largeur, :prix_peinture_m2,
      :poncage_categorie, :poncage_forfait,
      :rebouchage_categorie, :rebouchage_forfait,
      :ratissage_categorie, :ratissage_forfait)
  end
end
