# Conversions « Devis demandé (import) » au format CSV de Google Ads, pour la
# feuille Google Sheets « JF Habitat — conversions Ads » (cellule A1 :
# =IMPORTDATA("https://www.jfhabitat.fr/flux/conversions-ads/<jeton>")), que
# Google Ads relit chaque nuit à 5h32. Avant, il fallait y recoller le CSV de
# l'admin à la main : la feuille était restée figée du 27/07 au 09/11.
#
# Hérite de ActionController::Base, pas d'ApplicationController : le robot de
# Google n'est pas un navigateur « moderne » (allow_browser le refuserait) et
# ne doit compter ni comme visiteur ni comme étape du tunnel.
#
# Le fichier ne contient aucune donnée personnelle (identifiant de clic,
# heure, valeur), mais il dit combien de leads arrivent : jeton secret, et
# 404 sur tout le reste pour ne pas révéler que l'adresse existe.
class FluxConversionsAdsController < ActionController::Base
  def show
    attendu = ENV["CONVERSIONS_ADS_JETON"].to_s
    unless attendu.length >= 32 && ActiveSupport::SecurityUtils.secure_compare(params[:jeton].to_s, attendu)
      return head(:not_found)
    end

    response.headers["X-Robots-Tag"] = "noindex"
    send_data ConversionsAds.csv("lead", ConversionsAds.flux),
              filename: "conversions-google-ads.csv", type: "text/csv; charset=utf-8", disposition: "inline"
  end
end
