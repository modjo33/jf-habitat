class Admin::DepensesController < Admin::BaseController
  before_action :set_depense, only: [:edit, :update, :destroy, :justificatif]

  def index
    @annee = params[:annee].presence&.to_i || Date.current.year
    scope = Depense.annee(@annee).includes(:estimation)
    scope = scope.where(categorie: params[:categorie]) if params[:categorie].present?
    scope = scope.where(estimation_id: params[:estimation_id]) if params[:estimation_id].present?
    @depenses = scope.recentes

    @total_annee  = @depenses.sum(&:montant)
    @par_categorie = @depenses.group_by(&:categorie)
                              .transform_values { |ds| ds.sum(&:montant) }
                              .sort_by { |_, v| -v }
    @total_chantiers = @depenses.count { |d| d.estimation_id.present? }
  end

  def new
    @depense = Depense.new(
      date_depense: Date.current,
      estimation_id: params[:estimation_id],
      categorie: params[:categorie].presence_in(Depense::CATEGORIES.keys) || "materiaux"
    )
  end

  def create
    @depense = Depense.new(depense_params)
    attacher_justificatif
    if @depense.save
      redirect_to retour_apres_enregistrement,
                  notice: "Dépense de #{helpers.number_to_currency(@depense.montant, unit: '€', separator: ',', delimiter: ' ', format: '%n %u')} enregistrée."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    @depense.assign_attributes(depense_params)
    attacher_justificatif
    if @depense.save
      redirect_to admin_depenses_path, notice: "Dépense mise à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @depense.destroy
    redirect_to admin_depenses_path, notice: "Dépense supprimée."
  end

  # PDF servi depuis la base (Cloudinary ne délivre pas les PDF).
  def justificatif
    return head :not_found if @depense.justificatif_pdf.blank?
    send_data @depense.justificatif_pdf,
              filename: @depense.justificatif_pdf_nom.presence || "justificatif-#{@depense.id}.pdf",
              type: "application/pdf", disposition: "inline"
  end

  private

  def set_depense
    @depense = Depense.find(params[:id])
  end

  # Photo → Cloudinary (Active Storage). PDF → colonne binaire, sinon
  # Cloudinary le stocke mais renvoie un fichier vide au téléchargement.
  def attacher_justificatif
    fichier = params.dig(:depense, :justificatif)
    return if fichier.blank?

    if fichier.content_type == "application/pdf"
      @depense.justificatif_pdf = fichier.read
      @depense.justificatif_pdf_nom = fichier.original_filename
    else
      @depense.justificatif_image.attach(fichier)
    end
  end

  def retour_apres_enregistrement
    if @depense.estimation_id.present? && params[:retour] == "chantier"
      admin_estimation_path(@depense.estimation_id)
    else
      admin_depenses_path
    end
  end

  def depense_params
    params.require(:depense).permit(:date_depense, :fournisseur, :libelle, :montant,
                                    :categorie, :note, :estimation_id)
  end
end
