class Admin::DevisController < Admin::BaseController
  before_action :set_estimation, except: %i[index nouveau creer]

  # Écran de devis terrain (tablette).
  # Tous les devis chiffrés, quel que soit leur état — l'écran qui manquait
  # pour savoir ce qui est parti chez le client et ce qui a été accepté.
  def index
    @etat  = params[:etat].presence_in(Estimation::DEVIS_ETATS.keys)
    devis  = Estimation.avec_devis.includes(:client, :devis_analyse).order(updated_at: :desc)
    @devis = @etat ? devis.select { |e| e.devis_etat == @etat } : devis.to_a
    @compteurs = Estimation.avec_devis.to_a.group_by(&:devis_etat).transform_values(&:size)
    @montant_total   = @devis.sum { |e| e.devis_total.to_d }
    @montant_accepte = @devis.select(&:devis_accepte?).sum { |e| e.devis_total.to_d }
  end

  # Accepté hors signature à l'écran : devis renvoyé signé par mail, accord au
  # téléphone. Fait basculer le client en « gagné », donc le CA du tableau de bord.
  def accepter
    if @estimation.devis_vide?
      return redirect_back fallback_location: admin_devis_path,
                           alert: "Ce devis est à 0 € : rien à accepter."
    end
    @estimation.accepter_devis!
    redirect_back fallback_location: admin_devis_path,
                  notice: "Devis accepté — #{helpers.eur(@estimation.devis_total)} entrent dans le CA gagné."
  end

  # Devis refusé. Le pendant d'`accepter` : sans lui, marquer un devis perdu
  # laissait la fiche client active et le montant dans le CA potentiel.
  def refuser
    @estimation.perdre_devis!
    suite = @estimation.client&.statut == "perdu" ? " La fiche client passe en « perdu »." : ""
    redirect_back fallback_location: admin_devis_path,
                  notice: "Devis marqué comme refusé — le montant sort du CA potentiel.#{suite}"
  end

  def rouvrir
    @estimation.rouvrir_devis!
    redirect_back fallback_location: admin_devis_path, notice: "Devis rouvert."
  end

  # Créer un devis SANS estimation en ligne : chantier de bouche-à-oreille,
  # client rencontré sur place, ancien client qui rappelle. Jusqu'ici il fallait
  # un passage par le formulaire public, ce qui n'avait aucun sens ici.
  def nouveau
    @estimation = Estimation.new(origine: "manuel")
    @clients = Client.order(:nom)
  end

  def creer
    p = params.require(:estimation).permit(:nom, :email, :telephone, :adresse,
                                           :code_postal, :ville, :type_chantier, :client_id)
    client = Client.find_by(id: p[:client_id]) if p[:client_id].present?

    estimation = Estimation.new(
      origine: "manuel", statut: "contacte", devis_actif: true, tva_taux: 0,
      nom: client&.nom.presence || p[:nom],
      email: client&.email.presence || p[:email],
      telephone: client&.telephone.presence || p[:telephone],
      adresse: client&.adresse.presence || p[:adresse],
      code_postal: premier_code_postal(client&.code_postal, p[:code_postal]),
      ville: client&.ville.presence || p[:ville],
      type_chantier: p[:type_chantier].presence,
      client_id: client&.id
    )

    unless estimation.save
      @estimation = estimation
      @clients = Client.order(:nom)
      flash.now[:alert] = estimation.errors.full_messages.to_sentence
      return render :nouveau, status: :unprocessable_entity
    end

    # Toujours une fiche client derrière un devis : le CA du tableau de bord est
    # agrégé PAR CLIENT, un devis orphelin resterait invisible dans les chiffres.
    # ⚠️ Sans e-mail on ne peut pas passer par `upsert_from_estimation` : il
    # chercherait une fiche à l'e-mail vide et rattacherait au premier client
    # sans adresse (SCI JMR en l'occurrence). On crée alors une fiche neuve.
    if estimation.client.blank?
      fiche = if estimation.email.present?
                Client.upsert_from_estimation(estimation)
              else
                Client.create!(nom: estimation.nom, telephone: estimation.telephone,
                               adresse: estimation.adresse, code_postal: estimation.code_postal,
                               ville: estimation.ville, statut: "contacte",
                               derniere_interaction_at: Time.current)
              end
      estimation.update_column(:client_id, fiche.id)
    end

    redirect_to devis_lignes_admin_estimation_path(estimation),
                notice: "Devis créé — ajoute tes lignes, elles se regroupent par section."
  end

  def show
  end

  # Éditeur de devis en lignes libres (Vague 1) : bibliothèque + sections.
  def lignes
    @estimation.devis_recompute! if @estimation.devis_lignes.exists?
    @estimation.reload
    @prestations = Prestation.actives.ordered
  end

  # Génère le PDF détaillé depuis les lignes libres et le stocke en base
  # (DevisDocument) → l'écran d'envoi peut alors le prévisualiser et l'expédier.
  def generer_document
    unless @estimation.devis_lignes.exists?
      return redirect_to devis_lignes_admin_estimation_path(@estimation),
                         alert: "Ajoutez au moins une ligne avant de générer le PDF."
    end
    @estimation.devis_recompute!
    pdf = DevisLignePdfGenerator.new(@estimation.reload).generate.render
    doc = @estimation.devis_document || @estimation.build_devis_document
    doc.update!(data: pdf)
    redirect_to devis_envoi_admin_estimation_path(@estimation),
                notice: "PDF du devis généré — prévisualisez-le puis envoyez-le au client."
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

  # Conditions de paiement : acompte (%) + modalités libres (échéances…).
  def conditions
    @estimation.update!(conditions_params)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("devis_total_bar",
          partial: "admin/devis/bar", locals: { estimation: @estimation })
      end
      format.html { redirect_to devis_lignes_admin_estimation_path(@estimation) }
    end
  end

  # Échéancier de paiement (liste de versements en %) + modalités libres.
  def echeances
    @estimation.devis_conditions = params.dig(:estimation, :devis_conditions)
    @estimation.devis_echeances  = echeances_param
    @estimation.save!
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("devis_conditions_card",
            partial: "admin/devis/conditions", locals: { estimation: @estimation }),
          turbo_stream.replace("devis_total_bar",
            partial: "admin/devis/bar", locals: { estimation: @estimation })
        ]
      end
      format.html { redirect_to devis_lignes_admin_estimation_path(@estimation) }
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
    @estimation.update_column(:devis_envoye_at, Time.current)
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
    return if @estimation.devis_signe?

    redirect_si_devis_vide
  end

  # Enregistre la signature du client, verrouille en « gagné », envoie le mail.
  def sign
    return if redirect_si_devis_vide

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

  # Téléchargement / aperçu du PDF (signé si signature présente). Le générateur
  # est choisi selon le type de devis (lignes libres vs pièces/murs).
  def pdf
    return if redirect_si_devis_vide

    send_data @estimation.devis_pdf_generator.generate.render,
              filename: "devis-jf-habitat-#{@estimation.reference}.pdf",
              type: "application/pdf", disposition: "inline"
  end

  private

  # Un devis à 0 € n'est pas un devis : c'est un devis qu'on a ouvert sans le
  # remplir. Le laisser sortir en PDF ou passer à la signature ferait envoyer
  # au client un document vide à la place de son chiffrage.
  def redirect_si_devis_vide
    return false unless @estimation.devis_vide?

    cible = @estimation.devis_lignes? ? devis_lignes_admin_estimation_path(@estimation)
                                      : devis_admin_estimation_path(@estimation)
    redirect_to cible,
                alert: "Ce devis est encore à 0 € : rien n'y a été chiffré. " \
                       "Ajoutez les prestations avant de sortir le PDF ou de le faire signer " \
                       "(l'estimation en ligne du client, elle, reste consultable sur sa fiche)."
    true
  end

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

  # La fiche client peut porter, dans sa case code postal, autre chose qu'un
  # code postal — une ville y a déjà été saisie par erreur, et une espace
  # invisible devant les chiffres suffit à faire échouer la validation
  # « 5 chiffres » de l'estimation. Comme la fiche l'emporte sur la saisie, le
  # devis devenait impossible à créer sans qu'on voie pourquoi.
  # On retient donc le premier candidat réellement valide.
  def premier_code_postal(*candidats)
    valeurs = candidats.map { |v| v.to_s.strip }.compact_blank
    valeurs.find { |v| v.match?(/\A\d{5}\z/) } || valeurs.first
  end

  def set_estimation
    @estimation = Estimation.find(params[:id])
  end

  def extras_params
    params.require(:estimation).permit(:devis_trajet_prix_jour, :devis_trajet_jours,
                                       :devis_consommables, :devis_consommables_libelle)
  end

  # Normalise l'échéancier reçu (tableau de { libelle, pct }) : on retire les
  # lignes vides et on stocke le % en chaîne (nil = « le reste »).
  def echeances_param
    Array(params[:echeances]).filter_map do |e|
      lib = e[:libelle].to_s.strip
      pct = e[:pct].to_s.strip
      next if lib.blank? && pct.blank?
      { "libelle" => lib, "pct" => (pct.blank? ? nil : pct) }
    end
  end

  def conditions_params
    params.require(:estimation).permit(:devis_acompte_pct, :devis_conditions)
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
