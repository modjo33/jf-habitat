class CreateClientDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :client_documents do |t|
      t.references :client, null: false, foreign_key: true
      t.string :titre, null: false
      t.string :nom_fichier
      t.binary :contenu, null: false
      t.integer :taille
      t.timestamps
    end
  end
end
