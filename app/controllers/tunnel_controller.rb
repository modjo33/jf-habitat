# Balise appelée par le wizard à chaque écran atteint.
#
# Les écrans du tunnel n'existent que côté client (une seule page, Stimulus) :
# sans cet appel, le serveur ne voit que l'arrivée et la soumission, donc
# jamais l'endroit où le visiteur décroche.
class TunnelController < ApplicationController
  # Un parcours complet = une dizaine d'appels ; la marge est large mais couvre
  # les allers-retours dans le tunnel sans laisser un script marteler la table.
  rate_limit to: 200, within: 10.minutes, only: :create, key: "tunnel_suivi"

  def create
    suivre_etape(params[:etape].to_s, detail: params[:detail].to_s.presence)
    head :no_content
  end
end
