class CreateClientNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :client_notes do |t|
      t.references :client, null: false, foreign_key: true
      t.text       :body,   null: false
      t.string     :auteur, default: "Admin"
      t.timestamps
    end
    add_index :client_notes, [:client_id, :created_at]
  end
end
