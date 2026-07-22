class CreateDepenses < ActiveRecord::Migration[8.1]
  def change
    create_table :depenses do |t|
      # Rattachée à un chantier, ou nulle = frais généraux (véhicule, outillage…)
      t.references :estimation, null: true, foreign_key: true

      t.date    :date_depense, null: false
      t.string  :fournisseur
      t.string  :libelle,   null: false
      t.decimal :montant,   precision: 10, scale: 2, null: false
      t.string  :categorie, null: false, default: "materiaux"
      t.text    :note

      # Justificatif PDF stocké EN BASE : Cloudinary accepte les PDF mais refuse
      # de les livrer (téléchargement vide, cf. DevisDocument). Les photos de
      # tickets, elles, partent normalement sur Cloudinary via Active Storage.
      t.binary :justificatif_pdf
      t.string :justificatif_pdf_nom

      t.timestamps
    end

    add_index :depenses, :date_depense
    add_index :depenses, :categorie
  end
end
