class EstimationsController < ApplicationController
  # create : action sensible (écrit en base + envoie des emails) → quota strict.
  rate_limit to: 20, within: 1.hour, only: :create, key: "estimation_create"
  # preview : calcul en lecture seule appelé à chaque saisie → quota large et séparé,
  # sinon le simple remplissage du formulaire épuiserait le quota et bloquerait la soumission.
  rate_limit to: 300, within: 10.minutes, only: :preview, key: "estimation_preview"
  rate_limit to: 10, within: 1.hour, only: :telephone, key: "estimation_telephone"

  def new
    @estimation = Estimation.new
    @estimation.estimation_lines.build(mode_saisie: "surface", type_piece: "salon")
    # Point de départ de l'entonnoir : combien de clics publicitaires arrivent
    # réellement jusqu'ici.
    suivre_etape("arrivee")
  end

  def preview
    context = params.permit(:code_postal, :etage, :ascenseur).to_h
    @preview = EstimationCalculatorService.preview(params[:lines] || [], context: context)
    respond_to do |format|
      format.turbo_stream
      format.json { render json: preview_payload(@preview) }
    end
  end

  def create
    @estimation = Estimation.new(estimation_params)
    # Pas de forçage du taux : la colonne vaut 0 par défaut (franchise en base).
    @estimation.assign_attributes(source_attributes)

    if @estimation.save
      suivre_etape("soumis")
      attach_or_create_client(@estimation)
      # `deliver_now` et PAS `deliver_later` : l'adaptateur de jobs est :async,
      # sa file vit dans la mémoire du conteneur web — un redémarrage (déploiement,
      # crash) au mauvais moment perdait le mail SANS AUCUNE TRACE. Pour l'email
      # qui signale un nouveau lead, c'est inacceptable. Chaque envoi est isolé
      # dans son rescue : un SMTP en panne ne doit ni priver le client de sa
      # confirmation, ni surtout faire échouer la création du lead (le rescue
      # global de l'action afficherait « une erreur est survenue » alors que
      # l'estimation est enregistrée).
      envoyer_sans_bloquer { LeadMailer.nouveau_lead(@estimation).deliver_now }
      envoyer_sans_bloquer { LeadMailer.confirmation_client(@estimation).deliver_now }
      envoyer_sans_bloquer { SmsNotificationService.notify_new_lead(@estimation) }
      # Signale la conversion (lead) à la page de confirmation — fire une seule fois via le flash,
      # donc pas de double comptage si le client recharge / revient sur son devis plus tard.
      flash[:lead_converted] = true
      flash[:lead_value] = @estimation.total_ttc.to_f
      flash[:lead_reference] = @estimation.reference
      redirect_to estimation_path(reference: @estimation.reference)
    else
      @estimation.estimation_lines.build(mode_saisie: "surface", type_piece: "salon") if @estimation.estimation_lines.empty?
      render :new, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "[EstimationsController#create] failed: #{e.class} · #{e.message}"
    @estimation.estimation_lines.build(mode_saisie: "surface", type_piece: "salon") if @estimation.estimation_lines.empty?
    flash.now[:alert] = "Une erreur est survenue. Merci de réessayer dans quelques instants."
    render :new, status: :unprocessable_entity
  end

  # Téléphone demandé AVANT le prix — décision de Johan du 30/09/2026.
  # Mesuré du 25 au 30/09 avec le prix en clair : 4 visiteurs ont vu leur
  # devis (dont 10 115 € le 29/09), aucun n'a tapé le bouton d'envoi. Ils
  # repartaient avec le prix et on n'avait rien pour les rappeler. On demande
  # donc UN seul champ, le numéro, et le contact entre dans le CRM tout de
  # suite (action « Rappeler » datée du jour), avant même d'afficher le prix.
  # ⚠️ Différent du gate d'avant le 28/08 : c'était le formulaire complet
  # (nom + e-mail + téléphone…) devant un devis flouté.
  def telephone
    saisie = params.permit(:telephone, :projet, :total, :site_web)
    # Pot de miel : on répond OK sans rien créer.
    return head(:no_content) if saisie[:site_web].present?

    telephone = saisie[:telephone].to_s.gsub(/[[:space:].\-()]/, "")
    unless telephone.match?(Client::FORMAT_TELEPHONE)
      return render(json: { erreur: "Le téléphone doit être un numéro français à 10 chiffres." },
                    status: :unprocessable_entity)
    end

    total = saisie[:total].to_s[/\d+/]
    projet = saisie[:projet].to_s.strip.first(500)
    client = Client.find_by(telephone: telephone) ||
             Client.new(nom: Client::NOM_PROVISOIRE, telephone: telephone, statut: "nouveau")
    client.statut = "nouveau" if client.statut == "perdu"
    montant = total ? " — a vu un devis de #{total} € TTC" : ""
    client.prochaine_action = "Rappeler #{telephone} (estimateur#{montant})"
    client.prochaine_action_date = Date.current
    client.derniere_interaction_at = Time.current
    client.save!

    contexte = contexte_telephone
    detail = [ "Téléphone laissé sur l'estimateur, avant l'affichage du prix · #{contexte}",
               total && "Devis affiché : #{total} € TTC",
               projet.presence && "Projet : #{projet}" ].compact.join("\n")
    client.client_notes.create!(auteur: "Site", body: detail)

    suivre_etape("tel_donne", detail: total)
    resume = [ total && "devis vu #{total} € TTC", projet.presence ].compact.join(" · ")
    envoyer_sans_bloquer { LeadMailer.demande_rappel(client, "Estimateur : #{resume}", contexte).deliver_now }
    envoyer_sans_bloquer { SmsNotificationService.notify_rappel(client, "estimateur, #{resume}") }
    head :no_content
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[EstimationsController#telephone] #{e.message}"
    render json: { erreur: "Ce numéro n'a pas pu être enregistré." }, status: :unprocessable_entity
  end

  def show
    @estimation = Estimation.find_by!(reference: params[:reference])

    respond_to do |format|
      format.html
      format.pdf do
        pdf = DevisPdfGenerator.new(@estimation).generate
        send_data pdf.render,
                  filename: "devis-jf-habitat-#{@estimation.reference}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      end
    end
  end

  private

  # Un envoi (mail, SMS) qui échoue se log et c'est tout : le lead est déjà
  # en base, c'est lui qui compte.
  def envoyer_sans_bloquer
    yield
  rescue => e
    Rails.logger.error "[EstimationsController#create] notification échouée : #{e.class} · #{e.message}"
  end

  # « Google Ads · mobile » : d'où vient la personne, pour la note et le mail.
  def contexte_telephone
    source = { "ads" => "Google Ads", "autre" => "campagne", "direct" => "direct" }[source_tunnel]
    [ "/estimation/new", source, appareil_tunnel ].compact.join(" · ")
  end

  # Rattache l'estimation à un Client existant (par email) ou en crée un.
  # Erreur silencieuse : la création du Client ne doit pas faire échouer le lead.
  def attach_or_create_client(estimation)
    client = Client.upsert_from_estimation(estimation)
    estimation.update_column(:client_id, client.id)
  rescue => e
    Rails.logger.warn "[EstimationsController#create] client upsert failed: #{e.class} · #{e.message}"
  end

  # Devis affiché EN CLAIR avant les coordonnées — décision du 28/08/2026,
  # renversement du gate historique. Mesuré du 29/07 au 27/08 : 42 visiteurs
  # Ads sur l'écran contact, 3 soumissions ; les visiteurs tapaient le bouton
  # champs vides pour voir ce que cachait le flou. La fourchette exposait déjà
  # le prix : le flou ne protégeait plus que le détail, en coûtant la
  # confiance. Le formulaire devient une offre (PDF + rappel), plus un péage.
  def preview_payload(preview)
    lines = (preview[:lines] || []).map do |line|
      line.slice(:piece, :type_piece_label, :prestation_label, :gamme_label, :surface, :options, :total)
    end
    {
      lines: lines,
      surface_totale: preview[:surface_totale],
      count: preview[:count] || lines.size,
      total_ttc: preview[:total_ttc]
    }
  end

  def estimation_params
    params.require(:estimation).permit(
      :nom, :email, :telephone, :adresse, :code_postal, :ville,
      :delai, :message, :type_chantier, :etage, :ascenseur,
      photos: [],
      estimation_lines_attributes: [
        :id, :piece, :prestation, :gamme, :type_piece, :mode_saisie,
        :surface, :longueur, :largeur, :hauteur,
        :poncage, :poncage_peinture, :depose_evacuation,
        :_destroy
      ]
    )
  end
end
