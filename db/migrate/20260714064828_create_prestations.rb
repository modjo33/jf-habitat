class CreatePrestations < ActiveRecord::Migration[8.1]
  def change
    create_table :prestations do |t|
      t.string  :nom, null: false
      t.text    :description
      t.string  :unite, null: false, default: "m2"
      t.decimal :prix, precision: 10, scale: 2, default: "0.0"
      t.string  :categorie, null: false, default: "autre"
      t.integer :position, null: false, default: 0
      t.boolean :actif, null: false, default: true
      t.timestamps
    end
  end
end
