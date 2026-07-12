class CreateMurs < ActiveRecord::Migration[8.1]
  def change
    create_table :murs do |t|
      t.references :piece, null: false, foreign_key: true
      t.string  :libelle, null: false
      # type de surface : "mur" (longueur × hauteur) ou "plafond" (longueur × largeur)
      t.string  :kind, null: false, default: "mur"
      t.decimal :longueur, precision: 6, scale: 2, default: "0.0"
      t.decimal :hauteur,  precision: 6, scale: 2, default: "0.0"
      t.decimal :largeur,  precision: 6, scale: 2, default: "0.0"

      # Peinture (tout compris prépa + 2 couches), €/m² ajustable sur site.
      t.decimal :prix_peinture_m2, precision: 8, scale: 2, default: "0.0"

      # Préparations forfaitaires (catégorie + montant € ajustable sur site).
      t.string  :poncage_categorie,    default: "aucun"
      t.decimal :poncage_forfait,      precision: 8, scale: 2, default: "0.0"
      t.string  :rebouchage_categorie, default: "aucun"
      t.decimal :rebouchage_forfait,   precision: 8, scale: 2, default: "0.0"

      t.integer :position, null: false, default: 0

      # Totaux mémorisés (calculés dans le modèle).
      t.decimal :surface_nette, precision: 10, scale: 2, default: "0.0"
      t.decimal :total,         precision: 10, scale: 2, default: "0.0"

      t.timestamps
    end
    add_index :murs, [:piece_id, :position]
  end
end
