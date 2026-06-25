class Admin::ClientsController < Admin::BaseController
  before_action :set_client, only: [:show, :update]

  def index
    @q          = params[:q].to_s.strip
    @statut     = params[:statut].presence
    @clients    = Client.recents
    @clients    = @clients.where("nom ILIKE :q OR email ILIKE :q OR telephone ILIKE :q", q: "%#{@q}%") if @q.present?
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
    @estimations = @client.estimations.order(created_at: :desc)
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
