class CreateEtapeTunnels < ActiveRecord::Migration[8.1]
  def change
    create_table :etape_tunnels do |t|
      t.string   :visite, null: false, limit: 32
      t.string   :etape,  null: false
      t.string   :source, null: false, default: "direct"
      t.string   :appareil, null: false, default: "autre"
      t.datetime :created_at, null: false
    end

    # Une visite ne compte qu'une fois par étape : un aller-retour dans le
    # tunnel ne doit pas gonfler les chiffres. L'index porte l'unicité, les
    # écritures passent en INSERT ... ON CONFLICT DO NOTHING.
    add_index :etape_tunnels, [ :visite, :etape ], unique: true
    add_index :etape_tunnels, :created_at
  end
end
