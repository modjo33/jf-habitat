class CreateCampagneAds < ActiveRecord::Migration[8.0]
  def change
    # Suivi manuel de la campagne Google Ads (pas d'API Ads branchée) :
    # Johan saisit la dépense cumulée, l'admin calcule le reste + les alertes.
    create_table :campagne_ads do |t|
      t.string  :nom, default: "Travaux Gironde Sud"
      t.decimal :budget_total, precision: 10, scale: 2, default: 900
      t.decimal :depense_cumulee, precision: 10, scale: 2, default: 0
      t.decimal :cout_journalier, precision: 8, scale: 2, default: 20
      t.date    :depense_maj_le
      t.date    :validation_deadline, default: "2026-08-06"
      t.boolean :active, default: true, null: false
      t.timestamps
    end
  end
end
