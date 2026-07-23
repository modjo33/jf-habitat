# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_23_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "campagne_ads", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.decimal "budget_total", precision: 10, scale: 2, default: "900.0"
    t.decimal "cout_journalier", precision: 8, scale: 2, default: "20.0"
    t.datetime "created_at", null: false
    t.decimal "depense_cumulee", precision: 10, scale: 2, default: "0.0"
    t.date "depense_maj_le"
    t.string "nom", default: "Travaux Gironde Sud"
    t.datetime "updated_at", null: false
    t.date "validation_deadline", default: "2026-08-06"
  end

  create_table "client_notes", force: :cascade do |t|
    t.string "auteur", default: "Admin"
    t.text "body", null: false
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "created_at"], name: "index_client_notes_on_client_id_and_created_at"
    t.index ["client_id"], name: "index_client_notes_on_client_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "adresse"
    t.string "code_postal"
    t.datetime "created_at", null: false
    t.datetime "derniere_interaction_at"
    t.string "email"
    t.decimal "montant_devis_manuel", precision: 10, scale: 2
    t.string "nom", null: false
    t.text "notes_internes"
    t.text "prochaine_action"
    t.date "prochaine_action_date"
    t.string "statut", default: "nouveau", null: false, comment: "nouveau | contacte | rdv_pris | devis_envoye | gagne | perdu"
    t.string "telephone"
    t.datetime "updated_at", null: false
    t.string "ville"
    t.index ["derniere_interaction_at"], name: "index_clients_on_derniere_interaction_at"
    t.index ["email"], name: "index_clients_on_email", unique: true
    t.index ["prochaine_action_date"], name: "index_clients_on_prochaine_action_date"
    t.index ["statut"], name: "index_clients_on_statut"
  end

  create_table "declaration_periodes", force: :cascade do |t|
    t.integer "annee", null: false
    t.decimal "ca_declare", precision: 10, scale: 2, null: false
    t.decimal "cotisations_estimees", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.date "declaree_le", null: false
    t.integer "trimestre", null: false
    t.datetime "updated_at", null: false
    t.index ["annee", "trimestre"], name: "index_declaration_periodes_on_annee_and_trimestre", unique: true
  end

  create_table "deductions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "hauteur", precision: 6, scale: 2, default: "0.0"
    t.string "libelle", default: "Ouverture"
    t.decimal "longueur", precision: 6, scale: 2, default: "0.0"
    t.bigint "mur_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["mur_id", "position"], name: "index_deductions_on_mur_id_and_position"
    t.index ["mur_id"], name: "index_deductions_on_mur_id"
  end

  create_table "depenses", force: :cascade do |t|
    t.string "categorie", default: "materiaux", null: false
    t.datetime "created_at", null: false
    t.date "date_depense", null: false
    t.bigint "estimation_id"
    t.string "fournisseur"
    t.binary "justificatif_pdf"
    t.string "justificatif_pdf_nom"
    t.string "libelle", null: false
    t.decimal "montant", precision: 10, scale: 2, null: false
    t.text "note"
    t.datetime "updated_at", null: false
    t.index ["categorie"], name: "index_depenses_on_categorie"
    t.index ["date_depense"], name: "index_depenses_on_date_depense"
    t.index ["estimation_id"], name: "index_depenses_on_estimation_id"
  end

  create_table "devis_analyses", force: :cascade do |t|
    t.integer "alertes_count", default: 0, null: false
    t.decimal "autres_frais", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "benefice_net_cache", precision: 10, scale: 2
    t.datetime "calcule_at"
    t.decimal "cout_materiaux_saisi", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.bigint "estimation_id", null: false
    t.decimal "heures_par_jour", precision: 4, scale: 1, default: "7.0", null: false
    t.decimal "heures_saisies", precision: 8, scale: 2
    t.decimal "marge_securite_pct", precision: 5, scale: 2, default: "10.0", null: false
    t.string "niveau"
    t.text "note"
    t.decimal "objectif_horaire", precision: 6, scale: 2, null: false
    t.decimal "part_materiaux_max_pct", precision: 5, scale: 2, default: "35.0", null: false
    t.decimal "revenu_horaire_cache", precision: 8, scale: 2
    t.decimal "seuil_marge_alerte_pct", precision: 5, scale: 2, default: "20.0", null: false
    t.decimal "taux_cfp", precision: 4, scale: 2, null: false
    t.decimal "taux_cma", precision: 4, scale: 2, null: false
    t.decimal "taux_cotisations", precision: 5, scale: 2, null: false
    t.datetime "taux_figes_at", null: false
    t.decimal "taux_impot", precision: 5, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["estimation_id"], name: "index_devis_analyses_on_estimation_id", unique: true
    t.index ["niveau"], name: "index_devis_analyses_on_niveau"
  end

  create_table "devis_documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.binary "data"
    t.bigint "estimation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["estimation_id"], name: "index_devis_documents_on_estimation_id", unique: true
  end

  create_table "devis_lignes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "estimation_id", null: false
    t.string "libelle", null: false
    t.integer "position", default: 0, null: false
    t.bigint "prestation_id"
    t.decimal "prix_unitaire", precision: 10, scale: 2, default: "0.0"
    t.decimal "quantite", precision: 10, scale: 3, default: "1.0"
    t.string "section", default: "Travaux", null: false
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.string "unite", default: "forfait", null: false
    t.datetime "updated_at", null: false
    t.index ["estimation_id", "position"], name: "index_devis_lignes_on_estimation_id_and_position"
    t.index ["estimation_id"], name: "index_devis_lignes_on_estimation_id"
    t.index ["prestation_id"], name: "index_devis_lignes_on_prestation_id"
  end

  create_table "encaissements", force: :cascade do |t|
    t.bigint "client_id"
    t.datetime "created_at", null: false
    t.date "date_encaissement", null: false
    t.bigint "facture_id"
    t.string "libelle", null: false
    t.string "mode_reglement", default: "virement", null: false
    t.decimal "montant", precision: 10, scale: 2, null: false
    t.string "reference"
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_encaissements_on_client_id"
    t.index ["date_encaissement"], name: "index_encaissements_on_date_encaissement"
    t.index ["facture_id"], name: "index_encaissements_on_facture_id"
  end

  create_table "estimation_lines", force: :cascade do |t|
    t.decimal "coef_applique", precision: 5, scale: 3, default: "1.0"
    t.datetime "created_at", null: false
    t.boolean "depose_evacuation", default: false, null: false
    t.bigint "estimation_id", null: false
    t.string "gamme", null: false
    t.decimal "hauteur", precision: 6, scale: 2
    t.decimal "largeur", precision: 6, scale: 2
    t.decimal "longueur", precision: 6, scale: 2
    t.string "mode_saisie", default: "surface", null: false
    t.string "piece", null: false
    t.boolean "poncage", default: false, null: false
    t.boolean "poncage_peinture", default: false, null: false
    t.string "prestation", null: false
    t.decimal "prix_unitaire", precision: 10, scale: 2, null: false
    t.decimal "surface", precision: 8, scale: 2, null: false
    t.decimal "total", precision: 10, scale: 2, null: false
    t.string "type_piece", default: "autre", null: false
    t.datetime "updated_at", null: false
    t.index ["estimation_id"], name: "index_estimation_lines_on_estimation_id"
  end

  create_table "estimations", force: :cascade do |t|
    t.string "adresse"
    t.boolean "ascenseur", default: true, null: false
    t.bigint "client_id"
    t.string "code_postal"
    t.decimal "coef_etage", precision: 5, scale: 3, default: "1.0"
    t.decimal "coef_region", precision: 5, scale: 3, default: "1.0"
    t.datetime "created_at", null: false
    t.string "delai"
    t.integer "devis_acompte_pct"
    t.boolean "devis_actif", default: false, null: false
    t.text "devis_conditions"
    t.decimal "devis_consommables", precision: 10, scale: 2, default: "0.0"
    t.string "devis_consommables_libelle"
    t.jsonb "devis_echeances", default: [], null: false
    t.string "devis_remise_type"
    t.decimal "devis_remise_valeur", precision: 10, scale: 2, default: "0.0"
    t.string "devis_signataire"
    t.string "devis_signature_ip"
    t.datetime "devis_signe_at"
    t.datetime "devis_signe_envoye_at"
    t.decimal "devis_total", precision: 10, scale: 2, default: "0.0"
    t.decimal "devis_total_brut", precision: 10, scale: 2, default: "0.0"
    t.decimal "devis_trajet_jours", precision: 6, scale: 1, default: "1.0"
    t.decimal "devis_trajet_prix_jour", precision: 10, scale: 2, default: "0.0"
    t.string "email", null: false
    t.integer "etage", default: 0, null: false
    t.string "gclid"
    t.string "landing_page"
    t.text "message"
    t.string "nom", null: false
    t.string "reference", null: false
    t.string "referrer"
    t.string "statut", default: "nouveau", null: false
    t.decimal "surface_totale", precision: 10, scale: 2, default: "0.0"
    t.string "telephone", null: false
    t.decimal "total_ht", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_ttc", precision: 10, scale: 2, default: "0.0"
    t.decimal "tva_taux", precision: 5, scale: 2, default: "10.0"
    t.string "type_chantier"
    t.datetime "updated_at", null: false
    t.string "utm_campaign"
    t.string "utm_content"
    t.string "utm_medium"
    t.string "utm_source"
    t.string "utm_term"
    t.string "ville"
    t.index ["client_id"], name: "index_estimations_on_client_id"
    t.index ["created_at"], name: "index_estimations_on_created_at"
    t.index ["email"], name: "index_estimations_on_email"
    t.index ["gclid"], name: "index_estimations_on_gclid"
    t.index ["reference"], name: "index_estimations_on_reference", unique: true
    t.index ["utm_source"], name: "index_estimations_on_utm_source"
  end

  create_table "etape_tunnels", force: :cascade do |t|
    t.string "appareil", default: "autre", null: false
    t.datetime "created_at", null: false
    t.string "etape", null: false
    t.string "source", default: "direct", null: false
    t.string "visite", limit: 32, null: false
    t.index ["created_at"], name: "index_etape_tunnels_on_created_at"
    t.index ["visite", "etape"], name: "index_etape_tunnels_on_visite_and_etape", unique: true
  end

  create_table "facture_lignes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "facture_id", null: false
    t.string "libelle", null: false
    t.integer "position", default: 0, null: false
    t.decimal "prix_unitaire", precision: 10, scale: 2
    t.decimal "quantite", precision: 10, scale: 2
    t.string "section"
    t.decimal "total", precision: 10, scale: 2, default: "0.0", null: false
    t.string "unite", default: "m2", null: false
    t.datetime "updated_at", null: false
    t.index ["facture_id"], name: "index_facture_lignes_on_facture_id"
  end

  create_table "factures", force: :cascade do |t|
    t.string "chantier_adresse"
    t.bigint "client_id", null: false
    t.text "conditions"
    t.datetime "created_at", null: false
    t.date "date_emission", null: false
    t.datetime "envoyee_at"
    t.bigint "estimation_id"
    t.string "numero", null: false
    t.string "objet"
    t.binary "pdf_data"
    t.datetime "pdf_genere_at"
    t.string "statut", default: "brouillon", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_factures_on_client_id"
    t.index ["date_emission"], name: "index_factures_on_date_emission"
    t.index ["estimation_id"], name: "index_factures_on_estimation_id"
    t.index ["numero"], name: "index_factures_on_numero", unique: true
  end

  create_table "media_slots", force: :cascade do |t|
    t.string "alt_text"
    t.datetime "created_at", null: false
    t.text "description", comment: "Notice pour l'admin : où la photo s'affiche"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_media_slots_on_key", unique: true
  end

  create_table "murs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "gamme", default: "milieu", null: false
    t.decimal "hauteur", precision: 6, scale: 2, default: "0.0"
    t.string "kind", default: "mur", null: false
    t.decimal "largeur", precision: 6, scale: 2, default: "0.0"
    t.string "libelle", null: false
    t.decimal "longueur", precision: 6, scale: 2, default: "0.0"
    t.bigint "piece_id", null: false
    t.string "poncage_categorie", default: "aucun"
    t.decimal "poncage_forfait", precision: 8, scale: 2, default: "0.0"
    t.integer "position", default: 0, null: false
    t.decimal "prix_peinture_m2", precision: 8, scale: 2, default: "0.0"
    t.string "ratissage_categorie", default: "aucun", null: false
    t.decimal "ratissage_forfait", precision: 8, scale: 2, default: "0.0"
    t.string "rebouchage_categorie", default: "aucun"
    t.decimal "rebouchage_forfait", precision: 8, scale: 2, default: "0.0"
    t.decimal "surface_nette", precision: 10, scale: 2, default: "0.0"
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.string "type_chantier", default: "renovation", null: false
    t.datetime "updated_at", null: false
    t.index ["piece_id", "position"], name: "index_murs_on_piece_id_and_position"
    t.index ["piece_id"], name: "index_murs_on_piece_id"
  end

  create_table "pieces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "estimation_id", null: false
    t.decimal "hauteur_sous_plafond", precision: 6, scale: 2, default: "2.5"
    t.string "nom", null: false
    t.integer "position", default: 0, null: false
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.string "type_piece"
    t.datetime "updated_at", null: false
    t.index ["estimation_id", "position"], name: "index_pieces_on_estimation_id_and_position"
    t.index ["estimation_id"], name: "index_pieces_on_estimation_id"
  end

  create_table "prestations", force: :cascade do |t|
    t.boolean "actif", default: true, null: false
    t.string "categorie", default: "autre", null: false
    t.decimal "cout_matiere_unite", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.text "description"
    t.string "nom", null: false
    t.integer "position", default: 0, null: false
    t.decimal "prix", precision: 10, scale: 2, default: "0.0"
    t.decimal "rendement_m2_h", precision: 6, scale: 2
    t.string "unite", default: "m2", null: false
    t.datetime "updated_at", null: false
  end

  create_table "rdvs", force: :cascade do |t|
    t.string "adresse"
    t.boolean "all_day", default: false, null: false
    t.string "categorie", default: "visite_metre", null: false
    t.bigint "client_id"
    t.datetime "created_at", null: false
    t.datetime "ends_at"
    t.bigint "estimation_id"
    t.text "notes"
    t.datetime "starts_at", null: false
    t.string "statut", default: "prevu", null: false
    t.string "titre", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_rdvs_on_client_id"
    t.index ["estimation_id"], name: "index_rdvs_on_estimation_id"
    t.index ["starts_at"], name: "index_rdvs_on_starts_at"
  end

  create_table "realisations", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "legende", null: false
    t.string "metier", null: false, comment: "peinture | placo | parquet"
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_realisations_on_active_and_position"
    t.index ["position"], name: "index_realisations_on_position"
  end

  create_table "reglage_declarations", force: :cascade do |t|
    t.decimal "allocation_journaliere", precision: 6, scale: 2, default: "50.15"
    t.decimal "are_mensuelle", precision: 8, scale: 2, default: "1524.6"
    t.datetime "created_at", null: false
    t.boolean "deduire_are", default: false, null: false
    t.date "fin_droits_are"
    t.decimal "heures_par_forfait", precision: 5, scale: 2, default: "1.0"
    t.decimal "heures_par_jour", precision: 4, scale: 1, default: "7.0"
    t.decimal "jours_travailles_mois", precision: 4, scale: 1, default: "18.0"
    t.decimal "marge_securite_pct", precision: 5, scale: 2, default: "10.0"
    t.decimal "objectif_horaire_force", precision: 6, scale: 2
    t.decimal "part_materiaux_max_pct", precision: 5, scale: 2, default: "35.0"
    t.decimal "revenu_mensuel_cible", precision: 8, scale: 2, default: "2000.0"
    t.decimal "seuil_marge_alerte_pct", precision: 5, scale: 2, default: "20.0"
    t.decimal "taux_cfp", precision: 4, scale: 2, default: "0.3"
    t.decimal "taux_cma", precision: 4, scale: 2, default: "0.48"
    t.decimal "taux_cotisations", precision: 5, scale: 2, default: "21.2"
    t.decimal "taux_impot", precision: 5, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.boolean "versement_liberatoire", default: false, null: false
  end

  create_table "site_texts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", comment: "Notice pour l'admin : où le texte s'affiche"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value", default: "", null: false
    t.index ["key"], name: "index_site_texts_on_key", unique: true
  end

  create_table "tarifs", force: :cascade do |t|
    t.boolean "actif", default: true, null: false
    t.decimal "cout_matiere_unite", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.text "description"
    t.text "details"
    t.string "gamme", null: false
    t.string "prestation", null: false
    t.decimal "prix_m2", precision: 10, scale: 2, null: false
    t.decimal "rendement_m2_h", precision: 6, scale: 2
    t.string "unite", default: "m2", null: false
    t.datetime "updated_at", null: false
    t.index ["prestation", "gamme"], name: "index_tarifs_on_prestation_and_gamme", unique: true
  end

  create_table "zones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "largeur", precision: 6, scale: 2, default: "0.0"
    t.string "libelle", default: "Partie"
    t.decimal "longueur", precision: 6, scale: 2, default: "0.0"
    t.bigint "mur_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["mur_id", "position"], name: "index_zones_on_mur_id_and_position"
    t.index ["mur_id"], name: "index_zones_on_mur_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "client_notes", "clients"
  add_foreign_key "deductions", "murs"
  add_foreign_key "depenses", "estimations"
  add_foreign_key "devis_analyses", "estimations"
  add_foreign_key "devis_documents", "estimations"
  add_foreign_key "devis_lignes", "estimations"
  add_foreign_key "devis_lignes", "prestations"
  add_foreign_key "encaissements", "clients"
  add_foreign_key "encaissements", "factures"
  add_foreign_key "estimation_lines", "estimations"
  add_foreign_key "estimations", "clients"
  add_foreign_key "facture_lignes", "factures"
  add_foreign_key "factures", "clients"
  add_foreign_key "factures", "estimations"
  add_foreign_key "murs", "pieces"
  add_foreign_key "pieces", "estimations"
  add_foreign_key "rdvs", "clients"
  add_foreign_key "rdvs", "estimations"
  add_foreign_key "zones", "murs"
end
