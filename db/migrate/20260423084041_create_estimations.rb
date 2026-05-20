class CreateEstimations < ActiveRecord::Migration[8.1]
  def change
    create_table :estimations do |t|
      t.string :nom, null: false
      t.string :email, null: false
      t.string :telephone, null: false
      t.string :adresse
      t.string :code_postal
      t.string :ville
      t.string :delai
      t.text :message
      t.decimal :total_ht, precision: 10, scale: 2, default: 0
      t.decimal :total_ttc, precision: 10, scale: 2, default: 0
      t.decimal :tva_taux, precision: 5, scale: 2, default: 10.0
      t.string :statut, default: "nouveau", null: false
      t.string :reference, null: false
      t.string :type_chantier

      t.timestamps
    end

    add_index :estimations, :email
    add_index :estimations, :reference, unique: true
    add_index :estimations, :created_at
  end
end
