class Admin::ClientsController < Admin::BaseController
  before_action :set_client, only: [:show, :update, :destroy]

  def index
    @q          = params[:q].to_s.strip
    @statut     = params[:statut].presence
    @clients    = Client.recents
    if @q.present?
      # nom/email/tél/ville/CP sur le client + référence d'estimation via EXISTS
      # (sous-requête → pas de doublon de client s'il a plusieurs estimations).
      @clients = @clients.where(
        "clients.nom ILIKE :q OR clients.email ILIKE :q OR clients.telephone ILIKE :q " \
        "OR clients.ville ILIKE :q OR clients.code_postal ILIKE :q " \
        "OR EXISTS (SELECT 1 FROM estimations e WHERE e.client_id = clients.id AND e.reference ILIKE :q)",
        q: "%#{@q}%"
      )
    end
    @clients    = @clients.par_statut(@statut) if @statut.present?
  end

  def kanban
    @clients_by_statut = Client::STATUTS.keys.index_with do |s|
      Client.par_statut(s).recents.to_a
    end
  end

  def new
    @client = Client.new(statut: "nouveau")
  end

  def create
    @client = Client.new(client_params)
    @client.derniere_interaction_at = Time.current
    if @client.save
      redirect_to admin_client_path(@client), notice: "Client créé."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @notes       = @client.client_notes.recent
    @estimations = @client.estimations.order(created_at: :desc).with_attached_devis_signature
    # Estimations ayant un devis PDF prêt (sans charger le binaire).
    @devis_doc_ids = DevisDocument.where(estimation_id: @estimations.map(&:id)).pluck(:estimation_id).to_set
  end

  def update
    @client.assign_attributes(client_params)
    if @client.save
      @client.touch(:derniere_interaction_at)
      redirect_to admin_client_path(@client), notice: "Client mis à jour."
    else
      @notes       = @client.client_notes.recent
      @estimations = @client.estimations.order(created_at: :desc)
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    nom = @client.nom
    @client.destroy # estimations conservées (nullify), notes supprimées
    redirect_to admin_clients_path, notice: "Client « #{nom} » supprimé."
  end

  private

  def set_client
    @client = Client.find(params[:id])
  end

  def client_params
    params.require(:client).permit(
      :nom, :email, :telephone, :adresse, :code_postal, :ville,
      :statut, :montant_devis_manuel, :notes_internes, :prochaine_action, :prochaine_action_date
    )
  end
end
