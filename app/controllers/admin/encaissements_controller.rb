class Admin::EncaissementsController < Admin::BaseController
  before_action :set_encaissement, only: [:edit, :update, :destroy]

  def index
    @annee = params[:annee].presence&.to_i || Date.current.year
    @encaissements = Encaissement.annee(@annee).includes(:client).recents
    @total_annee = @encaissements.sum(&:montant)

    respond_to do |format|
      format.html
      # Livre des recettes officiel : export chronologique de l'année.
      format.csv do
        send_data livre_des_recettes_csv,
                  filename: "livre-des-recettes-#{@annee}.csv",
                  type: "text/csv; charset=utf-8"
      end
    end
  end

  def new
    @encaissement = Encaissement.new(
      date_encaissement: Date.current,
      client_id: params[:client_id],
      montant: params[:montant]
    )
    if @encaissement.client
      @encaissement.libelle ||= "Chantier #{@encaissement.client.nom}"
    end
  end

  def create
    @encaissement = Encaissement.new(encaissement_params)
    if @encaissement.save
      @encaissement.client&.touch(:derniere_interaction_at)
      redirect_to admin_encaissements_path, notice: "Encaissement de #{helpers.number_to_currency(@encaissement.montant, unit: '€', separator: ',', delimiter: ' ', format: '%n %u')} enregistré."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @encaissement.update(encaissement_params)
      redirect_to admin_encaissements_path, notice: "Encaissement mis à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @encaissement.destroy
    redirect_to admin_encaissements_path, notice: "Encaissement supprimé."
  end

  private

  def set_encaissement
    @encaissement = Encaissement.find(params[:id])
  end

  def encaissement_params
    params.require(:encaissement).permit(:date_encaissement, :montant, :mode_reglement, :libelle, :reference, :client_id)
  end

  def livre_des_recettes_csv
    lignes = Encaissement.annee(@annee).includes(:client).chronologique
    csv = "Date;Libellé;Client;Référence;Mode de règlement;Montant (EUR)\n"
    lignes.each do |e|
      champs = [
        e.date_encaissement.strftime("%d/%m/%Y"),
        e.libelle, e.client&.nom, e.reference,
        e.mode_reglement_label,
        format("%.2f", e.montant).tr(".", ",")
      ]
      csv << champs.map { |c| %("#{c.to_s.gsub('"', '""')}") }.join(";") << "\n"
    end
    csv << ";;;;Total;#{format('%.2f', lignes.sum(:montant)).tr('.', ',')}\n"
    # BOM UTF-8 pour qu'Excel ouvre les accents correctement.
    "\xEF\xBB\xBF" + csv
  end
end
