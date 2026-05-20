class CreateEstimationLines < ActiveRecord::Migration[8.1]
  def change
    create_table :estimation_lines do |t|
      t.references :estimation, null: false, foreign_key: true
      t.string :piece, null: false
      t.string :prestation, null: false
      t.string :gamme, null: false
      t.decimal :surface, precision: 8, scale: 2, null: false
      t.decimal :prix_unitaire, precision: 10, scale: 2, null: false
      t.decimal :total, precision: 10, scale: 2, null: false

      t.timestamps
    end
  end
end
