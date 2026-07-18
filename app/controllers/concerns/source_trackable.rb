# Capture l'origine du visiteur (Google Ads / UTM) à l'atterrissage et la
# conserve en session jusqu'à la soumission du formulaire d'estimation.
#
# Sans ça, impossible de dire si un lead vient de la pub ou du référencement
# naturel : on ne pouvait que corréler des dates.
#
# Attribution au PREMIER contact : si la session porte déjà une source, on ne
# l'écrase pas (un visiteur qui arrive par Ads puis revient en direct reste
# attribué à Ads).
module SourceTrackable
  extend ActiveSupport::Concern

  UTM_KEYS = %w[utm_source utm_medium utm_campaign utm_term utm_content].freeze
  TRACKED  = (UTM_KEYS + %w[gclid]).freeze
  MAX_LEN  = 255
  # Formats qui ne sont jamais une page d'atterrissage.
  IGNORED_FORMATS = %w[json turbo_stream pdf csv xml].freeze

  included do
    before_action :capture_source, if: :trackable_request?
  end

  private

  # On exclut par la négative : un client qui envoie `Accept: */*` a un
  # request.format à "*/*" (et non html), donc un test `format.html?` laisserait
  # passer à côté de vrais atterrissages.
  def trackable_request?
    request.get? && !request.xhr? &&
      !IGNORED_FORMATS.include?(request.format.symbol.to_s)
  end

  def capture_source
    return if session[:source_captured]

    captured = TRACKED.index_with { |k| truncate_param(params[k]) }.compact
    # Pas de marqueur de campagne → on ne fige rien : le visiteur pourra
    # arriver sur une page interne puis revenir avec un gclid.
    return if captured.empty?

    session[:source] = captured.merge(
      "landing_page" => truncate_param(request.path),
      "referrer"     => truncate_param(request.referer)
    )
    session[:source_captured] = true
  end

  def truncate_param(value)
    v = value.to_s.strip
    v.presence && v[0, MAX_LEN]
  end

  # Attributs à recopier sur l'enregistrement au moment de la soumission.
  def source_attributes
    (session[:source] || {}).slice(
      *TRACKED, "landing_page", "referrer"
    )
  end
end
