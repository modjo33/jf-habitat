class AddDevisPaiementToEstimations < ActiveRecord::Migration[8.1]
  def change
    # Conditions de paiement du devis : acompte à la commande (%) et modalités
    # libres (échéances, moyens de paiement…). Affichées sur le PDF.
    add_column :estimations, :devis_acompte_pct, :integer
    add_column :estimations, :devis_conditions, :text
  end
end
