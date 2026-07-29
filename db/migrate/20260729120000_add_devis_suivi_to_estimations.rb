# Suivi de la vie d'un devis, pour l'écran /admin/devis : quand il est parti
# chez le client, et quand il a été accepté. L'acceptation existait déjà, mais
# uniquement par la signature à l'écran chez le client — un devis renvoyé signé
# par mail n'avait aucun moyen d'être enregistré comme tel.
class AddDevisSuiviToEstimations < ActiveRecord::Migration[8.1]
  def change
    add_column :estimations, :devis_envoye_at, :datetime
    add_column :estimations, :devis_accepte_at, :datetime
    add_index  :estimations, :devis_accepte_at
  end
end
