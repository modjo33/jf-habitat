class AddDevisEstimatifToEstimations < ActiveRecord::Migration[8.1]
  def change
    add_column :estimations, :devis_estimatif, :boolean, default: false, null: false
  end
end
