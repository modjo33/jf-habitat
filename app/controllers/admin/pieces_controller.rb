class Admin::PiecesController < Admin::BaseController
  include DevisRecomputable
  before_action :set_estimation, only: :create

  def create
    pos = @estimation.pieces.maximum(:position).to_i + 1
    @piece = @estimation.pieces.create!(
      nom: params.dig(:piece, :nom).presence || "Pièce #{pos + 1}",
      type_piece: "autre", hauteur_sous_plafond: 2.5, position: pos
    )
    render turbo_stream: [
      turbo_stream.append("pieces", partial: "admin/devis/piece", locals: { piece: @piece }),
      turbo_stream.replace("devis_total_bar", partial: "admin/devis/bar", locals: { estimation: @estimation })
    ]
  end

  def update
    @piece = Piece.find(params[:id])
    @piece.update!(params.require(:piece).permit(:nom, :type_piece, :hauteur_sous_plafond))
    head :no_content
  end

  def destroy
    @piece = Piece.find(params[:id])
    @estimation = @piece.estimation
    @piece.destroy
    @piece = nil
    render_devis_totals(extra: turbo_stream.remove("piece_#{params[:id]}"))
  end

  private

  def set_estimation
    @estimation = Estimation.find(params[:estimation_id])
  end
end
