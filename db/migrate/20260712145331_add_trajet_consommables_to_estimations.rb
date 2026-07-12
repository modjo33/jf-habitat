class AddTrajetConsommablesToEstimations < ActiveRecord::Migration[8.1]
  def change
    add_column :estimations, :devis_trajet_prix_jour,      :decimal, precision: 10, scale: 2, default: "0.0"
    add_column :estimations, :devis_trajet_jours,          :decimal, precision: 6,  scale: 1, default: "1.0"
    add_column :estimations, :devis_consommables,          :decimal, precision: 10, scale: 2, default: "0.0"
    add_column :estimations, :devis_consommables_libelle,  :string
  end
end
