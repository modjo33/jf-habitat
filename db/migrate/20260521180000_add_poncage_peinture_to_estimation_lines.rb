class AddPoncagePeintureToEstimationLines < ActiveRecord::Migration[8.1]
  def change
    add_column :estimation_lines, :poncage_peinture, :boolean, default: false, null: false
  end
end
