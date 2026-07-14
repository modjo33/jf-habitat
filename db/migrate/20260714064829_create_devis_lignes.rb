class CreateDevisLignes < ActiveRecord::Migration[8.1]
  def change
    create_table :devis_lignes do |t|
      t.references :estimation, null: false, foreign_key: true
      t.references :prestation, foreign_key: true
      t.string  :section, null: false, default: "Travaux"
      t.string  :libelle, null: false
      t.text    :description
      t.decimal :quantite, precision: 10, scale: 3, default: "1.0"
      t.string  :unite, null: false, default: "forfait"
      t.decimal :prix_unitaire, precision: 10, scale: 2, default: "0.0"
      t.decimal :total, precision: 10, scale: 2, default: "0.0"
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :devis_lignes, [:estimation_id, :position]
  end
end
