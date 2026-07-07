class CreateComptaDeclarations < ActiveRecord::Migration[8.0]
  def change
    # Livre des recettes : chaque encaissement réellement reçu (date de réception
    # des fonds, pas date de facture — c'est la règle micro-BIC).
    create_table :encaissements do |t|
      t.references :client, foreign_key: true, null: true
      t.date :date_encaissement, null: false
      t.decimal :montant, precision: 10, scale: 2, null: false
      t.string :mode_reglement, null: false, default: "virement"
      t.string :libelle, null: false
      t.string :reference
      t.timestamps
    end
    add_index :encaissements, :date_encaissement

    # Historique des déclarations URSSAF trimestrielles (archive au moment du clic
    # « Marquer déclarée » : le CA affiché ensuite ne bouge plus même si un
    # encaissement est corrigé après coup).
    create_table :declaration_periodes do |t|
      t.integer :annee, null: false
      t.integer :trimestre, null: false
      t.decimal :ca_declare, precision: 10, scale: 2, null: false
      t.decimal :cotisations_estimees, precision: 10, scale: 2
      t.date :declaree_le, null: false
      t.timestamps
    end
    add_index :declaration_periodes, [:annee, :trimestre], unique: true

    # Réglages (ligne unique) : situation ARE + taux, modifiables sans redéployer
    # quand les barèmes changent.
    create_table :reglage_declarations do |t|
      t.decimal :are_mensuelle, precision: 8, scale: 2, default: 1524.60
      t.decimal :allocation_journaliere, precision: 6, scale: 2, default: 50.15
      t.date :fin_droits_are
      t.decimal :taux_cotisations, precision: 5, scale: 2, default: 21.2
      t.decimal :taux_cfp, precision: 4, scale: 2, default: 0.3
      t.decimal :taux_cma, precision: 4, scale: 2, default: 0.48
      t.boolean :versement_liberatoire, default: false, null: false
      t.timestamps
    end
  end
end
