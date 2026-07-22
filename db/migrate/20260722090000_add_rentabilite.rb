class AddRentabilite < ActiveRecord::Migration[8.1]
  def change
    # --- Réglages de rentabilité (mêmes réglages que les déclarations : un
    #     seul endroit pour les taux, jamais de valeur en dur dans le code).
    change_table :reglage_declarations, bulk: true do |t|
      t.decimal :revenu_mensuel_cible,   precision: 8, scale: 2, default: 2000.0
      t.decimal :jours_travailles_mois,  precision: 4, scale: 1, default: 18.0
      t.decimal :heures_par_jour,        precision: 4, scale: 1, default: 7.0
      t.decimal :objectif_horaire_force, precision: 6, scale: 2               # nil = déduit du revenu cible
      # Déduire l'ARE abaisse l'objectif horaire tant que les droits courent —
      # et le fait bondir à leur fin. Désactivé par défaut : on chiffre sur une
      # activité qui tient debout seule, pas sur une aide temporaire.
      t.boolean :deduire_are,            null: false, default: false
      t.decimal :taux_impot,             precision: 5, scale: 2, default: 0.0 # provision, base = 50 % du CA
      t.decimal :marge_securite_pct,     precision: 5, scale: 2, default: 10.0
      t.decimal :seuil_marge_alerte_pct, precision: 5, scale: 2, default: 20.0
      t.decimal :part_materiaux_max_pct, precision: 5, scale: 2, default: 35.0
      t.decimal :heures_par_forfait,     precision: 5, scale: 2, default: 1.0 # ligne au forfait, sans surface
    end

    # --- Barème interne : rendement et coût matière, sur les DEUX
    #     bibliothèques qui alimentent les devis. Jamais affiché au client.
    change_table :tarifs, bulk: true do |t|
      t.decimal :rendement_m2_h,     precision: 6, scale: 2
      t.decimal :cout_matiere_unite, precision: 8, scale: 2
    end

    change_table :prestations, bulk: true do |t|
      t.decimal :rendement_m2_h,     precision: 6, scale: 2
      t.decimal :cout_matiere_unite, precision: 8, scale: 2
    end

    # --- Analyse d'un devis. Table séparée des `estimations` : le devis client
    #     et l'analyse interne ne se croisent jamais (aucun risque de fuite
    #     dans un PDF ou un mail), et le figeage des taux y est naturel.
    create_table :devis_analyses do |t|
      t.references :estimation, null: false, foreign_key: true, index: { unique: true }

      # Saisies facultatives : nil => on retient la valeur calculée du barème.
      t.decimal :heures_saisies,        precision: 8, scale: 2
      t.decimal :cout_materiaux_saisi,  precision: 10, scale: 2
      t.decimal :autres_frais,          precision: 10, scale: 2, null: false, default: 0.0
      t.text    :note

      # Photographie des taux au moment de l'analyse : un changement de barème
      # ne doit JAMAIS recalculer un devis déjà établi.
      t.decimal :taux_cotisations,   precision: 5, scale: 2, null: false
      t.decimal :taux_cfp,           precision: 4, scale: 2, null: false
      t.decimal :taux_cma,           precision: 4, scale: 2, null: false
      t.decimal :taux_impot,         precision: 5, scale: 2, null: false, default: 0.0
      t.decimal :objectif_horaire,   precision: 6, scale: 2, null: false
      t.decimal :heures_par_jour,    precision: 4, scale: 1, null: false, default: 7.0
      t.decimal :marge_securite_pct, precision: 5, scale: 2, null: false, default: 10.0
      t.decimal :seuil_marge_alerte_pct, precision: 5, scale: 2, null: false, default: 20.0
      t.decimal :part_materiaux_max_pct, precision: 5, scale: 2, null: false, default: 35.0

      t.datetime :taux_figes_at, null: false
      t.timestamps
    end
  end
end
