class Admin::RealisationsController < Admin::BaseController
  before_action :set_realisation, only: [:edit, :update, :destroy]

  def index
    @realisations = Realisation.ordered
    @fallback_active = Realisation.active.count.zero?
  end

  def new
    @realisation = Realisation.new(active: true)
  end

  def create
    @realisation = Realisation.new(realisation_params)
    if @realisation.save
      redirect_to admin_realisations_path, notice: "Réalisation ajoutée."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @realisation.update(realisation_params)
      redirect_to admin_realisations_path, notice: "Réalisation mise à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @realisation.destroy
    redirect_to admin_realisations_path, notice: "Réalisation supprimée."
  end

  # PATCH /admin/realisations/reorder  { positions: { id => position } }
  def reorder
    positions = params.require(:positions).to_unsafe_h
    Realisation.transaction do
      positions.each { |id, pos| Realisation.where(id: id).update_all(position: pos.to_i) }
    end
    head :no_content
  end

  private

  def set_realisation
    @realisation = Realisation.find(params[:id])
  end

  def realisation_params
    params.require(:realisation).permit(:legende, :metier, :position, :active, :photo)
  end
end
