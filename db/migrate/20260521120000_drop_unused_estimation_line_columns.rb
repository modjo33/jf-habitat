class DropUnusedEstimationLineColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :estimation_lines, :nb_portes, :integer, default: 0, null: false
    remove_column :estimation_lines, :nb_fenetres, :integer, default: 0, null: false
    remove_column :estimation_lines, :rebouchage_lourd, :boolean, default: false, null: false
    remove_column :estimation_lines, :depose_ancien, :boolean, default: false, null: false
    remove_column :estimation_lines, :preparation_speciale, :boolean, default: false, null: false
  end
end
