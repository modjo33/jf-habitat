class AddNiveauToDevisAnalyses < ActiveRecord::Migration[8.1]
  def change
    # Résultat dénormalisé du dernier calcul : la liste des estimations affiche
    # une pastille par ligne, recalculer l'analyse complète (pièces, murs,
    # barème Tarif) pour chacune ferait autant de rafales de requêtes.
    change_table :devis_analyses, bulk: true do |t|
      t.string   :niveau                                        # vert / orange / rouge
      t.decimal  :benefice_net_cache,  precision: 10, scale: 2
      t.decimal  :revenu_horaire_cache, precision: 8,  scale: 2
      t.integer  :alertes_count, null: false, default: 0
      t.datetime :calcule_at
    end
    add_index :devis_analyses, :niveau
  end
end
