class AddDevisEcheancesToEstimations < ActiveRecord::Migration[8.1]
  def change
    add_column :estimations, :devis_echeances, :jsonb, default: [], null: false
  end
end
