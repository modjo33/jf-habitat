class Admin::ClientNotesController < Admin::BaseController
  before_action :set_client

  def create
    note = @client.client_notes.build(note_params.merge(auteur: "Admin"))
    if note.save
      @client.touch(:derniere_interaction_at)
      redirect_to admin_client_path(@client), notice: "Note ajoutée."
    else
      redirect_to admin_client_path(@client), alert: note.errors.full_messages.to_sentence
    end
  end

  def destroy
    note = @client.client_notes.find(params[:id])
    note.destroy
    redirect_to admin_client_path(@client), notice: "Note supprimée."
  end

  private

  def set_client
    @client = Client.find(params[:client_id])
  end

  def note_params
    params.require(:client_note).permit(:body)
  end
end
