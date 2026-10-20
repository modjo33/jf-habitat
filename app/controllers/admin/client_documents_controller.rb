class Admin::ClientDocumentsController < Admin::BaseController
  before_action :set_client

  def create
    document = @client.client_documents.build(titre: params.dig(:client_document, :titre).presence)
    document.fichier = params.dig(:client_document, :fichier)
    if document.save
      redirect_to admin_client_path(@client), notice: "Document ajouté."
    else
      redirect_to admin_client_path(@client),
                  alert: document.errors.full_messages.to_sentence.presence || "Choisissez un fichier PDF ou une image."
    end
  end

  # Document servi depuis la base, ouvert dans le navigateur.
  def show
    document = @client.client_documents.find(params[:id])
    send_data document.contenu,
              filename: document.nom_piece_jointe,
              type: document.mime_type || "application/pdf", disposition: "inline"
  end

  def destroy
    @client.client_documents.find(params[:id]).destroy
    redirect_to admin_client_path(@client), notice: "Document supprimé."
  end

  private

  def set_client
    @client = Client.find(params[:client_id])
  end
end
