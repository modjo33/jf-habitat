# Début d'activité : l'URSSAF ne réclame rien pendant les premiers mois, puis
# regroupe toutes les périodes écoulées à une même date d'exigibilité. Pour
# Johan, mai / juin / juillet / août 2026 sont tous exigibles au 30/09/2026,
# alors que la règle courante (fin du mois suivant) donnerait le 31/08 pour
# juillet — soit une échéance annoncée un mois trop tôt.
#
# Cette date se lit sur autoentrepreneur.urssaf.fr → calendrier des échéances.
class AjouterPremiereExigibiliteUrssaf < ActiveRecord::Migration[8.1]
  def change
    add_column :reglage_declarations, :premiere_exigibilite_urssaf, :date
  end
end
