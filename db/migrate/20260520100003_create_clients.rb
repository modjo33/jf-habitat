class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.string :nom,           null: false
      t.string :email,         null: false
      t.string :telephone
      t.string :adresse
      t.string :code_postal
      t.string :ville
      t.string :statut,        null: false, default: "nouveau", comment: "nouveau | contacte | rdv_pris | devis_envoye | gagne | perdu"
      t.text   :notes_internes
      t.text   :prochaine_action
      t.date   :prochaine_action_date
      t.datetime :derniere_interaction_at
      t.timestamps
    end
    add_index :clients, :email, unique: true
    add_index :clients, :statut
    add_index :clients, :prochaine_action_date
    add_index :clients, :derniere_interaction_at
  end
end
