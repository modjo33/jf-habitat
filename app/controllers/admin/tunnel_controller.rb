class Admin::TunnelController < Admin::BaseController
  PERIODES = { "7" => "7 jours", "14" => "14 jours", "30" => "30 jours", "90" => "90 jours" }.freeze

  def index
    @jours    = PERIODES.key?(params[:jours]) ? params[:jours].to_i : 7
    @fin      = Date.current
    @debut    = @fin - (@jours - 1).days
    @source   = params[:source].presence_in(EtapeTunnel::SOURCES)
    @appareil = params[:appareil].presence_in(EtapeTunnel::APPAREILS)

    @entonnoir   = EtapeTunnel.entonnoir(debut: @debut, fin: @fin, source: @source, appareil: @appareil)
    @appels      = EtapeTunnel.appels(debut: @debut, fin: @fin, source: @source, appareil: @appareil)
    @par_source  = EtapeTunnel.par_source(debut: @debut, fin: @fin)
    @par_appareil = EtapeTunnel.par_appareil(debut: @debut, fin: @fin)
    @premiere_mesure = EtapeTunnel.minimum(:created_at)

    # Repère de coût : ce que la publicité a coûté sur la période, pour
    # rapprocher les visites mesurées de la dépense.
    @campagne = CampagneAds.instance if defined?(CampagneAds)
  end
end
