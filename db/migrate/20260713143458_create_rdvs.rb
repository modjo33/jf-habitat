class CreateRdvs < ActiveRecord::Migration[8.1]
  def change
    create_table :rdvs do |t|
      t.string   :titre, null: false
      t.string   :categorie, null: false, default: "visite_metre"
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.boolean  :all_day, null: false, default: false
      t.references :client, foreign_key: true
      t.references :estimation, foreign_key: true
      t.string   :adresse
      t.text     :notes
      t.string   :statut, null: false, default: "prevu"

      t.timestamps
    end
    add_index :rdvs, :starts_at
  end
end
