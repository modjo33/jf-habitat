class Admin::EstimationsController < Admin::BaseController
  before_action :set_estimation, only: [:show, :update, :destroy]

  def index
    @q = params[:q]
    @statut = params[:statut]
    # includes(:devis_analyse) : la pastille de rentabilité lit le verdict
    # dénormalisé, sans quoi chaque ligne déclencherait sa propre requête.
    @estimations = Estimation.includes(:devis_analyse).order(created_at: :desc)
    @estimations = @estimations.where("nom ILIKE :q OR email ILIKE :q OR reference ILIKE :q", q: "%#{@q}%") if @q.present?
    @estimations = @estimations.where(statut: @statut) if @statut.present?
  end

  def show
  end

  def update
    if @estimation.update(estimation_params)
      redirect_to admin_estimation_path(@estimation), notice: "Lead mis à jour."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @estimation.destroy
    redirect_to admin_estimations_path, notice: "Lead supprimé."
  end

  private

  def set_estimation
    @estimation = Estimation.find(params[:id])
  end

  def estimation_params
    params.require(:estimation).permit(:statut)
  end
end
