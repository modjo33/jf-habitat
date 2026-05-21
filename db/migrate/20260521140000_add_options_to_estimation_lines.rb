class AddOptionsToEstimationLines < ActiveRecord::Migration[8.1]
  def change
    add_column :estimation_lines, :poncage, :boolean, default: false, null: false
    add_column :estimation_lines, :depose_evacuation, :boolean, default: false, null: false
  end
end
