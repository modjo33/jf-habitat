class AddDetailToEtapeTunnels < ActiveRecord::Migration[8.0]
  def change
    # Motif du refus pour `envoi_bloque` : sans lui, on sait QUE la validation
    # a refusé, jamais POURQUOI — impossible de dire si c'est le téléphone qui
    # fait fuir ou une dimension aberrante. Message générique du wizard,
    # jamais la valeur saisie par le visiteur.
    add_column :etape_tunnels, :detail, :string, limit: 120
  end
end
