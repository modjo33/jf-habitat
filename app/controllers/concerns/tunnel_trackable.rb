# Enregistre le passage d'un visiteur aux étapes du tunnel d'estimation.
#
# Complément indispensable de GA4 : le tag Google est conditionné au
# consentement cookies, donc muet pour la majorité du trafic. Ici on ne mesure
# qu'un compteur agrégé, sans donnée personnelle (cf. EtapeTunnel).
module TunnelTrackable
  extend ActiveSupport::Concern

  # Un robot qui parcourt le site fausserait complètement le taux de passage.
  ROBOTS = /bot|crawl|spider|slurp|bingpreview|headless|lighthouse|pingdom|uptime|curl|wget|python-requests|facebookexternalhit|preview/i
  # L'ordre compte : un iPad se déclare aussi « Safari mobile ».
  TABLETTE = /ipad|tablet|playbook|silk|kindle|android(?!.*mobile)/i
  MOBILE   = /mobile|iphone|ipod|android|blackberry|opera mini|iemobile|windows phone/i

  private

  # Jeton aléatoire porté par la session Rails (cookie strictement nécessaire,
  # déjà présent) : sert uniquement à ne pas compter deux fois la même visite.
  def visite_tunnel
    session[:visite] ||= SecureRandom.hex(16)
  end

  def suivre_etape(etape, detail: nil)
    return if robot_tunnel?

    EtapeTunnel.enregistrer(
      visite: visite_tunnel,
      etape: etape,
      source: source_tunnel,
      appareil: appareil_tunnel,
      detail: detail
    )
  end

  def robot_tunnel?
    request.user_agent.to_s.match?(ROBOTS)
  end

  # S'appuie sur la source déjà capturée par SourceTrackable à l'atterrissage.
  def source_tunnel
    src = session[:source] || {}
    return "ads" if src.values_at("gclid", "gbraid", "wbraid").any?(&:present?) ||
                    src["utm_medium"].to_s.match?(/cpc|ppc|paid/i)
    return "autre" if src.any?

    "direct"
  end

  def appareil_tunnel
    ua = request.user_agent.to_s
    return "tablette"    if ua.match?(TABLETTE)
    return "mobile"      if ua.match?(MOBILE)
    return "ordinateur"  if ua.present?

    "autre"
  end
end
