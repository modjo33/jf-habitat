class CreateFactures < ActiveRecord::Migration[8.1]
  def change
    create_table :factures do |t|
      t.references :client,     null: false, foreign_key: true
      t.references :estimation, null: true,  foreign_key: true   # devis d'origine (facultatif)
      t.string  :numero,           null: false
      t.date    :date_emission,    null: false
      t.string  :statut,           null: false, default: "brouillon"
      t.string  :objet
      t.string  :chantier_adresse
      t.text    :conditions
      t.binary  :pdf_data                                        # PDF stocké en base (cf. DevisDocument)
      t.datetime :pdf_genere_at
      t.datetime :envoyee_at
      t.timestamps
    end
    add_index :factures, :numero, unique: true
    add_index :factures, :date_emission

    create_table :facture_lignes do |t|
      t.references :facture, null: false, foreign_key: true
      t.string  :section
      t.string  :libelle, null: false
      t.text    :description
      t.decimal :quantite,      precision: 10, scale: 2
      t.string  :unite,         null: false, default: "m2"
      t.decimal :prix_unitaire, precision: 10, scale: 2
      t.decimal :total,         precision: 10, scale: 2, null: false, default: 0
      t.integer :position,      null: false, default: 0
      t.timestamps
    end

    # Rattache un encaissement à sa facture : la facture en déduit son solde,
    # le livre des recettes reste la source de vérité des montants encaissés.
    add_reference :encaissements, :facture, null: true, foreign_key: true
  end
end
