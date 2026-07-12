class CreateZones < ActiveRecord::Migration[8.1]
  def change
    create_table :zones do |t|
      t.references :mur, null: false, foreign_key: true
      t.string  :libelle, default: "Partie"
      t.decimal :longueur, precision: 6, scale: 2, default: "0.0"
      t.decimal :largeur,  precision: 6, scale: 2, default: "0.0"
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :zones, [:mur_id, :position]
  end
end
