class CreatePieces < ActiveRecord::Migration[8.1]
  def change
    create_table :pieces do |t|
      t.references :estimation, null: false, foreign_key: true
      t.string  :nom, null: false
      t.string  :type_piece
      t.decimal :hauteur_sous_plafond, precision: 6, scale: 2, default: "2.5"
      t.integer :position, null: false, default: 0
      t.decimal :total, precision: 10, scale: 2, default: "0.0"

      t.timestamps
    end
    add_index :pieces, [:estimation_id, :position]
  end
end
