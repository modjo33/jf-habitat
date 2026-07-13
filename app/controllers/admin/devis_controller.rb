class Admin::DevisController < Admin::BaseController
  before_action :set_estimation

  # Écran de devis terrain (tablette).
  def show
  end

  # Pré-remplit les pièces depuis l'estimation web du client.
  def prefill
    @estimation.devis_prefill_from_web!
    redirect_to devis_admin_estimation_path(@estimation)
  end

  # Remise globale : % ou montant fixe.
  def remise
    @estimation.update!(remise_params)
    @estimation.devis_recompute!
    @estimation.reload
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("devis_total_bar",
          partial: "admin/devis/bar", locals: { estimation: @estimation })
      end
      format.html { redirect_to devis_admin_estimation_path(@estimation) }
    end
  end

  # Trajet + consommables (frais du chantier).
  def extras
    @estimation.update!(extras_params)
    @estimation.devis_recompute!
    @estimation.reload
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("devis_total_bar",
          partial: "admin/devis/bar", locals: { estimation: @estimation })
      end
      format.html { redirect_to devis_admin_estimation_path(@estimation) }
    end
  end

  # Télécharge / affiche le PDF du devis (stocké en base) — via l'admin (auth),
  # pas d'URL Cloudinary publique.
  def document_pdf
    doc = @estimation.devis_document
    unless doc&.data.present?
      return redirect_back fallback_location: admin_estimation_path(@estimation),
                           alert: "Aucun devis PDF."
    end
    send_data doc.data, filename: "devis-jf-habitat-#{@estimation.reference}.pdf",
              type: "application/pdf", disposition: "inline"
  end

  # Écran de composition du mail (message pré-rempli, modifiable).
  def envoi
    @message = "Bonjour #{@estimation.nom},\n\n"\
               "Suite à notre échange, veuillez trouver ci-joint votre devis détaillé "\
               "pour les travaux à réaliser.\n\n"\
               "Je reste à votre disposition pour toute question ou ajustement.\n\n"\
               "Bien cordialement,\nJohan — JF Habitat"
  end

  # Envoie le devis (PDF) au client par mail.
  def envoyer
    unless @estimation.devis_document&.data.present?
      return redirect_back fallback_location: admin_estimation_path(@estimation),
                           alert: "Aucun devis PDF à envoyer."
    end
    LeadMailer.devis_document(@estimation, params[:message]).deliver_now
    @estimation.update(statut: "devis_envoye") if @estimation.statut == "nouveau" || @estimation.statut == "contacte"
    if (c = @estimation.client) && %w[nouveau contacte rdv_pris].include?(c.statut)
      c.update(statut: "devis_envoye")
    end
    redirect_back fallback_location: admin_estimation_path(@estimation),
                  notice: "Devis envoyé à #{@estimation.email}."
  rescue => e
    Rails.logger.error "[Devis] envoi échoué : #{e.class} #{e.message}"
    redirect_back fallback_location: admin_estimation_path(@estimation),
                  alert: "Échec de l'envoi du devis. Réessayez."
  end

  # Récap client (lecture seule) + pavé de signature, ou état signé.
  def presentation
  end

  # Enregistre la signature du client, verrouille en « gagné », envoie le mail.
  def sign
    data = params[:signature_data].to_s
    unless data.start_with?("data:image/png")
      return redirect_to devis_presentation_admin_estimation_path(@estimation),
                         alert: "Signature manquante — merci de signer à l'écran."
    end

    png = Base64.decode64(data.split(",", 2).last)
    @estimation.finaliser_devis_signe!(
      signature_io: StringIO.new(png),
      signataire:   params[:signataire],
      ip:           request.remote_ip
    )
    envoyer_devis_signe
    redirect_to devis_presentation_admin_estimation_path(@estimation)
  end

  # Renvoyer le mail du devis signé.
  def resend
    unless @estimation.devis_signe?
      return redirect_to devis_presentation_admin_estimation_path(@estimation), alert: "Le devis n'est pas encore signé."
    end
    envoyer_devis_signe
    redirect_to devis_presentation_admin_estimation_path(@estimation)
  end

  # Téléchargement / aperçu du PDF (signé si signature présente).
  def pdf
    generator = DevisTerrainPdfGenerator.new(@estimation)
    send_data generator.generate.render,
              filename: "devis-jf-habitat-#{@estimation.reference}.pdf",
              type: "application/pdf", disposition: "inline"
  end

  private

  # Envoi synchrone pour un retour immédiat sur place ; en cas d'échec SMTP,
  # le devis reste signé et Johan peut « Renvoyer le mail ».
  def envoyer_devis_signe
    LeadMailer.devis_signe(@estimation).deliver_now
    @estimation.update_column(:devis_signe_envoye_at, Time.current)
    flash[:notice] = "Devis signé et envoyé à #{@estimation.email}."
  rescue => e
    Rails.logger.error "[Devis] envoi du mail signé échoué : #{e.class} #{e.message}"
    flash[:alert] = "Devis signé, mais l'envoi de l'e-mail a échoué. Utilisez « Renvoyer le mail »."
  end

  def set_estimation
    @estimation = Estimation.find(params[:id])
  end

  def extras_params
    params.require(:estimation).permit(:devis_trajet_prix_jour, :devis_trajet_jours,
                                       :devis_consommables, :devis_consommables_libelle)
  end

  def remise_params
    permitted = params.require(:estimation).permit(:devis_remise_type, :devis_remise_valeur)
    # "aucune" → on efface la remise.
    if permitted[:devis_remise_type].blank? || permitted[:devis_remise_type] == "aucune"
      permitted[:devis_remise_type] = nil
      permitted[:devis_remise_valeur] = 0
    end
    permitted
  end
end
