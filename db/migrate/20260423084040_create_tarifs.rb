class CreateTarifs < ActiveRecord::Migration[8.1]
  def change
    create_table :tarifs do |t|
      t.string :prestation, null: false
      t.string :gamme, null: false
      t.decimal :prix_m2, precision: 10, scale: 2, null: false
      t.string :unite, default: "m2", null: false
      t.boolean :actif, default: true, null: false
      t.text :description

      t.timestamps
    end

    add_index :tarifs, [:prestation, :gamme], unique: true
  end
end
