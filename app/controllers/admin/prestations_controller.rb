class Admin::PrestationsController < Admin::BaseController
  before_action :set_prestation, only: [:edit, :update, :destroy]

  def index
    @prestations_par_categorie = Prestation.ordered.group_by(&:categorie)
  end

  def new
    @prestation = Prestation.new(categorie: params[:categorie].presence || "peinture", unite: "m2")
  end

  def create
    @prestation = Prestation.new(prestation_params)
    if @prestation.save
      redirect_to admin_prestations_path, notice: "Prestation ajoutée à la bibliothèque."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @prestation.update(prestation_params)
      redirect_to admin_prestations_path, notice: "Prestation mise à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @prestation.destroy
    redirect_to admin_prestations_path, notice: "Prestation supprimée."
  end

  private

  def set_prestation
    @prestation = Prestation.find(params[:id])
  end

  def prestation_params
    params.require(:prestation).permit(:nom, :description, :unite, :prix, :categorie, :position, :actif,
                                       :rendement_m2_h, :cout_matiere_unite)
  end
end
