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

ActiveRecord::Schema[8.1].define(version: 2026_06_25_200000) do
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
    t.string "email", null: false
    t.integer "etage", default: 0, null: false
    t.text "message"
    t.string "nom", null: false
    t.string "reference", null: false
    t.decimal "remise_degressive", precision: 5, scale: 3, default: "0.0"
    t.string "statut", default: "nouveau", null: false
    t.decimal "surface_totale", precision: 10, scale: 2, default: "0.0"
    t.string "telephone", null: false
    t.decimal "total_ht", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_ttc", precision: 10, scale: 2, default: "0.0"
    t.decimal "tva_taux", precision: 5, scale: 2, default: "10.0"
    t.string "type_chantier"
    t.datetime "updated_at", null: false
    t.string "ville"
    t.index ["client_id"], name: "index_estimations_on_client_id"
    t.index ["created_at"], name: "index_estimations_on_created_at"
    t.index ["email"], name: "index_estimations_on_email"
    t.index ["reference"], name: "index_estimations_on_reference", unique: true
  end

  create_table "media_slots", force: :cascade do |t|
    t.string "alt_text"
    t.datetime "created_at", null: false
    t.text "description", comment: "Notice pour l'admin : où la photo s'affiche"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_media_slots_on_key", unique: true
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
    t.datetime "created_at", null: false
    t.text "description"
    t.text "details"
    t.string "gamme", null: false
    t.string "prestation", null: false
    t.decimal "prix_m2", precision: 10, scale: 2, null: false
    t.string "unite", default: "m2", null: false
    t.datetime "updated_at", null: false
    t.index ["prestation", "gamme"], name: "index_tarifs_on_prestation_and_gamme", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "client_notes", "clients"
  add_foreign_key "estimation_lines", "estimations"
  add_foreign_key "estimations", "clients"
end
