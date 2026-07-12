class RemoveRemiseDegressiveFromEstimations < ActiveRecord::Migration[8.1]
  def change
    remove_column :estimations, :remise_degressive, :decimal, precision: 5, scale: 3, default: "0.0"
  end
end
