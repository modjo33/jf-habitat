class EstimationsController < ApplicationController
  # create : action sensible (écrit en base + envoie des emails) → quota strict.
  rate_limit to: 20, within: 1.hour, only: :create, key: "estimation_create"
  # preview : calcul en lecture seule appelé à chaque saisie → quota large et séparé,
  # sinon le simple remplissage du formulaire épuiserait le quota et bloquerait la soumission.
  rate_limit to: 300, within: 10.minutes, only: :preview, key: "estimation_preview"

  def new
    @estimation = Estimation.new
    @estimation.estimation_lines.build(mode_saisie: "surface", type_piece: "salon")
  end

  def preview
    context = params.permit(:code_postal, :etage, :ascenseur).to_h
    @preview = EstimationCalculatorService.preview(params[:lines] || [], context: context)
    respond_to do |format|
      format.turbo_stream
      # Devis chiffré accessible uniquement après soumission des coordonnées :
      # on n'expose que les éléments factuels (pièces, surfaces), jamais les
      # prix unitaires ni les totaux.
      format.json { render json: gated_preview(@preview) }
    end
  end

  def create
    @estimation = Estimation.new(estimation_params)
    @estimation.tva_taux ||= 10.0
    @estimation.assign_attributes(source_attributes)

    if @estimation.save
      attach_or_create_client(@estimation)
      LeadMailer.nouveau_lead(@estimation).deliver_later
      LeadMailer.confirmation_client(@estimation).deliver_later
      SmsNotificationService.notify_new_lead(@estimation)
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

  # Rattache l'estimation à un Client existant (par email) ou en crée un.
  # Erreur silencieuse : la création du Client ne doit pas faire échouer le lead.
  def attach_or_create_client(estimation)
    client = Client.upsert_from_estimation(estimation)
    estimation.update_column(:client_id, client.id)
  rescue => e
    Rails.logger.warn "[EstimationsController#create] client upsert failed: #{e.class} · #{e.message}"
  end

  # Filtre la preview pour ne renvoyer côté client que des données sans prix.
  # Le devis chiffré complet n'est disponible qu'une fois les coordonnées
  # soumises (cf. action create + page show).
  def gated_preview(preview)
    safe_lines = (preview[:lines] || []).map do |line|
      line.slice(:piece, :prestation_label, :gamme_label, :surface, :options)
    end
    {
      lines: safe_lines,
      surface_totale: preview[:surface_totale],
      count: preview[:count] || safe_lines.size
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
