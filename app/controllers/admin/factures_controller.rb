class Admin::FacturesController < Admin::BaseController
  before_action :set_facture, only: [:show, :edit, :update, :destroy, :pdf, :regenerer]

  def index
    @annee = params[:annee].presence&.to_i || Date.current.year
    @factures = Facture.annee(@annee).includes(:client, :facture_lignes, :encaissements).recentes
    @total_annee    = @factures.sum(&:total)
    @encaisse_annee = @factures.sum(&:montant_encaisse)
    @impaye_annee   = @factures.reject { |f| f.statut == "annulee" }.sum(&:solde)
  end

  def show; end

  # Nouvelle facture : vierge, ou pré-remplie depuis un devis (?estimation_id=).
  def new
    @facture = if params[:estimation_id].present?
                 estimation = Estimation.find(params[:estimation_id])
                 Facture.depuis_estimation(estimation)
               else
                 Facture.new(date_emission: Date.current, client_id: params[:client_id])
               end
    @facture.facture_lignes.build(position: 0) if @facture.facture_lignes.empty?
  end

  def create
    @facture = Facture.new(facture_params)
    if @facture.save
      @facture.regenerer_pdf!
      redirect_to admin_facture_path(@facture), notice: "Facture #{@facture.numero} créée."
    else
      @facture.facture_lignes.build if @facture.facture_lignes.empty?
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @facture.facture_lignes.build(position: @facture.facture_lignes.size) if @facture.facture_lignes.empty?
  end

  def update
    if @facture.update(facture_params)
      @facture.regenerer_pdf!
      redirect_to admin_facture_path(@facture), notice: "Facture mise à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    numero = @facture.numero
    @facture.destroy
    redirect_to admin_factures_path, notice: "Facture #{numero} supprimée."
  end

  # PDF servi depuis la base (Cloudinary ne délivre pas les PDF — cf. DevisDocument).
  def pdf
    @facture.regenerer_pdf! if @facture.pdf_data.blank?
    send_data @facture.pdf_data,
              filename: "#{@facture.numero}.pdf",
              type: "application/pdf",
              disposition: params[:download] ? "attachment" : "inline"
  end

  def regenerer
    @facture.regenerer_pdf!
    redirect_to admin_facture_path(@facture), notice: "PDF régénéré."
  end

  private

  def set_facture
    @facture = Facture.find(params[:id])
  end

  def facture_params
    params.require(:facture).permit(
      :client_id, :estimation_id, :date_emission, :statut, :objet,
      :chantier_adresse, :conditions,
      facture_lignes_attributes: [:id, :section, :libelle, :description, :quantite,
                                  :unite, :prix_unitaire, :position, :_destroy]
    )
  end
end
