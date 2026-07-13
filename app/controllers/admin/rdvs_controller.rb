class Admin::RdvsController < Admin::BaseController
  before_action :set_rdv, only: [:edit, :update, :destroy]

  # Calendrier mensuel.
  def index
    @mois = parse_mois(params[:mois])
    debut = @mois.beginning_of_month.beginning_of_week(:monday)
    fin   = @mois.end_of_month.end_of_week(:monday)
    @jours = (debut..fin).to_a
    @rdvs_par_jour = rdvs_par_jour(debut, fin)
    @prochains = Rdv.actifs.a_venir.includes(:client).chrono.limit(8)
  end

  # Vue semaine.
  def semaine
    d = (Date.parse(params[:date]) rescue Date.current)
    @debut = d.beginning_of_week(:monday)
    @fin   = @debut.end_of_week(:monday)
    @jours = (@debut..@fin).to_a
    @rdvs_par_jour = rdvs_par_jour(@debut, @fin)
  end

  # Export iCalendar (abonnement téléphone).
  def ical
    send_data RdvIcal.feed(Rdv.actifs.order(:starts_at)),
              type: "text/calendar; charset=utf-8",
              filename: "jf-habitat-agenda.ics", disposition: "inline"
  end

  def new
    @rdv = Rdv.new(starts_at: default_start, categorie: params[:categorie].presence || "visite_metre")
    if (e = Estimation.find_by(id: params[:estimation_id]))
      @rdv.estimation = e
      @rdv.client     = e.client
      @rdv.adresse    = e.adresse_complete
      @rdv.titre      = "Visite / métré — #{e.nom}"
    end
    if (c = Client.find_by(id: params[:client_id]))
      @rdv.client   = c
      @rdv.adresse  = c.adresse_complete if @rdv.adresse.blank?
      @rdv.titre    = "Visite / métré — #{c.nom}"
    end
  end

  def create
    @rdv = Rdv.new(rdv_params)
    if @rdv.save
      redirect_to admin_rdvs_path(mois: @rdv.jour.strftime("%Y-%m")), notice: "RDV ajouté."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @rdv.update(rdv_params)
      redirect_to admin_rdvs_path(mois: @rdv.jour.strftime("%Y-%m")), notice: "RDV mis à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    mois = @rdv.jour.strftime("%Y-%m")
    @rdv.destroy
    redirect_to admin_rdvs_path(mois: mois), notice: "RDV supprimé."
  end

  private

  def set_rdv
    @rdv = Rdv.find(params[:id])
  end

  # Répartit les RDV sur chaque jour qu'ils couvrent (gère le multi-jours).
  def rdvs_par_jour(debut, fin)
    par_jour = Hash.new { |h, k| h[k] = [] }
    Rdv.where("starts_at <= ? AND COALESCE(ends_at, starts_at) >= ?", fin.end_of_day, debut.beginning_of_day)
       .includes(:client).chrono.each do |r|
      d0 = [r.jour, debut].max
      d1 = [r.date_fin, fin].min
      (d0..d1).each { |d| par_jour[d] << r }
    end
    par_jour
  end

  def parse_mois(str)
    Date.parse("#{str}-01")
  rescue ArgumentError, TypeError
    Date.current.beginning_of_month
  end

  def default_start
    d = (Date.parse(params[:date]) rescue Date.current)
    d.to_time.change(hour: 9)
  end

  def rdv_params
    params.require(:rdv).permit(:titre, :categorie, :starts_at, :ends_at, :all_day,
                                :client_id, :estimation_id, :adresse, :notes, :statut)
  end
end
