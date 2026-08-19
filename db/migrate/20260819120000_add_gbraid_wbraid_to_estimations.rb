# Sur iOS, la protection de la vie privée d'Apple remplace parfois le gclid
# par un gbraid (app→web) ou wbraid (web→app). Sans ces colonnes, un clic
# Google Ads depuis iPhone peut arriver sans aucun identifiant capturé :
# le lead serait attribué « direct » et invisible dans l'import de conversions.
class AddGbraidWbraidToEstimations < ActiveRecord::Migration[8.0]
  def change
    add_column :estimations, :gbraid, :string
    add_column :estimations, :wbraid, :string
  end
end
