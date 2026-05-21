class Admin::TarifsController < Admin::BaseController
  before_action :set_tarif, only: [:edit, :update, :destroy]

  def index
    @tarifs = Tarif.order(:prestation, :gamme)
    @by_categorie = @tarifs.group_by(&:categorie)
  end

  def new
    @tarif = Tarif.new
  end

  def create
    @tarif = Tarif.new(tarif_params)
    if @tarif.save
      redirect_to admin_tarifs_path, notice: "Tarif créé."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @tarif.update(tarif_params)
      redirect_to admin_tarifs_path, notice: "Tarif mis à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tarif.destroy
    redirect_to admin_tarifs_path, notice: "Tarif supprimé."
  end

  private

  def set_tarif
    @tarif = Tarif.find(params[:id])
  end

  def tarif_params
    params.require(:tarif).permit(:prestation, :gamme, :prix_m2, :description, :details, :actif)
  end
end
