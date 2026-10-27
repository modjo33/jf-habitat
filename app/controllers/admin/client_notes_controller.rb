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

  # Transforme le projet laissé sur l'estimateur en estimation, une seule fois :
  # un second clic renvoie vers celle déjà créée.
  def estimation
    note = @client.client_notes.find(params[:id])
    projet = ProjetEstimateur.new(note.donnees)
    return redirect_to(admin_client_path(@client), alert: "Cette note ne contient pas de projet.") unless projet.present?
    if (existante = projet.estimation)
      return redirect_to admin_estimation_path(existante)
    end

    estimation = projet.construire_estimation(@client, note)
    if estimation.save
      note.update!(donnees: note.donnees.merge("estimation_id" => estimation.id))
      @client.touch(:derniere_interaction_at)
      redirect_to admin_estimation_path(estimation),
                  notice: "Estimation #{estimation.reference} créée à partir du projet laissé sur l'estimateur."
    else
      redirect_to admin_client_path(@client),
                  alert: "Estimation impossible : #{estimation.errors.full_messages.to_sentence}"
    end
  end

  # PDF du devis estimatif affiché au visiteur qui a laissé son numéro sans
  # envoyer le formulaire (aucun PDF ne lui a été envoyé).
  def devis_estimatif
    note = @client.client_notes.find(params[:id])
    projet = ProjetEstimateur.new(note.donnees)
    return redirect_to(admin_client_path(@client), alert: "Cette note ne contient pas de projet.") unless projet.lignes.any?

    estimation = projet.estimation_pour_pdf(@client, note)
    send_data DevisPdfGenerator.new(estimation).generate.render,
              filename: "devis-estimatif-#{estimation.reference}.pdf",
              type: "application/pdf", disposition: "inline"
  end

  private

  def set_client
    @client = Client.find(params[:client_id])
  end

  def note_params
    params.require(:client_note).permit(:body)
  end
end
