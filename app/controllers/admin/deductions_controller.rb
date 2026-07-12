class Admin::DeductionsController < Admin::BaseController
  include DevisRecomputable

  PRESETS = {
    "porte"   => { libelle: "Porte",   longueur: 0.90, hauteur: 2.04 },
    "fenetre" => { libelle: "Fenêtre", longueur: 1.20, hauteur: 1.00 }
  }.freeze

  def create
    @mur = Mur.find(params[:mur_id])
    @piece = @mur.piece
    @estimation = @piece.estimation
    preset = PRESETS[params[:preset]] || { libelle: "Ouverture", longueur: 0, hauteur: 0 }
    pos = @mur.deductions.maximum(:position).to_i + 1
    @deduction = @mur.deductions.create!(preset.merge(position: pos))

    render_devis_totals(extra: turbo_stream.append("mur_#{@mur.id}_deductions",
      partial: "admin/devis/deduction", locals: { deduction: @deduction }))
  end

  def update
    @deduction = Deduction.find(params[:id])
    @mur = @deduction.mur
    @piece = @mur.piece
    @estimation = @piece.estimation
    @deduction.update!(deduction_params)
    # Surface de la ligne recalculée côté client (autosave_controller) pour ne pas
    # voler le focus sur tablette ; on ne rafraîchit que les totaux.
    render_devis_totals
  end

  def destroy
    @deduction = Deduction.find(params[:id])
    @mur = @deduction.mur
    @piece = @mur.piece
    @estimation = @piece.estimation
    id = @deduction.id
    @deduction.destroy
    render_devis_totals(extra: turbo_stream.remove("deduction_#{id}"))
  end

  private

  def deduction_params
    params.require(:deduction).permit(:libelle, :longueur, :hauteur)
  end
end
