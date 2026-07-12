class AddDevisFieldsToEstimations < ActiveRecord::Migration[8.1]
  def change
    # Devis terrain (outil admin) — totaux séparés du chiffrage web.
    add_column :estimations, :devis_actif, :boolean, default: false, null: false
    add_column :estimations, :devis_remise_type,   :string   # "pourcentage" | "montant" | nil
    add_column :estimations, :devis_remise_valeur, :decimal, precision: 10, scale: 2, default: "0.0"
    add_column :estimations, :devis_total_brut,    :decimal, precision: 10, scale: 2, default: "0.0"
    add_column :estimations, :devis_total,         :decimal, precision: 10, scale: 2, default: "0.0"
    add_column :estimations, :devis_signe_at,      :datetime
  end
end
