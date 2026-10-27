require "test_helper"

# Projet laissé sur l'estimateur avec le numéro (27/10/2026) : avant, la fiche
# client n'avait que le prix vu et une ligne de résumé. Les pièces, dimensions,
# travaux et précisions étaient perdus si le visiteur n'envoyait pas le
# formulaire.
class ProjetEstimateurTest < ActionDispatch::IntegrationTest
  AUTH = { "Authorization" => ActionController::HttpAuthentication::Basic
             .encode_credentials("admin", "jfhabitat2026") }.freeze
  JSON_HEADERS = { "Accept" => "application/json" }.freeze

  DETAILS = {
    chantier: "renovation", gamme: "milieu", etage: "1", code_postal: "33650",
    options: [ "poncage_peinture", "inconnue" ],
    pieces: [ { label: "Salon", type: "salon", travaux: [ "Peinture des murs" ], mode: "simple",
                surface_sol: 20, hauteur: 2.5, murs: 41.03, sol: 20, cloison: 0 } ],
    precisions: { etat: "Fissures à reboucher", teintes: "2 couleurs", profil: "" },
    lignes: [ { piece: "Salon", type_piece: "salon", prestation: "peinture_murs_reno", gamme: "milieu",
                mode_saisie: "surface", surface: "41.03", poncage: "0", poncage_peinture: "1", depose_evacuation: "0" },
              { piece: "Salon", prestation: "", surface: "5" } ],
    chiffrage: { total_ttc: 1234.5, lignes: [ { libelle: "Salon · Peinture murs", surface: 41.03, total: 1234.5 } ] }
  }.freeze

  setup do
    Tarif.create!(prestation: "peinture_murs_reno", gamme: "milieu", prix_m2: 22, unite: "m2")
    ActionMailer::Base.deliveries.clear
  end

  def laisser_numero(details = DETAILS)
    post telephone_estimation_path, params: { telephone: "0612345678", total: "1235", projet: "Salon · Peinture",
                                              details: details }, headers: JSON_HEADERS, as: :json
    assert_response :no_content
    Client.find_by!(telephone: "0612345678")
  end

  test "le numéro enregistre le projet complet sur la note, sans créer d'estimation" do
    client = nil
    assert_no_difference "Estimation.count" do
      client = laisser_numero
    end
    d = client.client_notes.last.donnees
    assert_equal "Salon", d["pieces"].first["label"]
    assert_equal 41.03, d["pieces"].first["murs"]
    assert_equal [ "poncage_peinture" ], d["options"], "une option inconnue est écartée"
    assert_equal 1, d["lignes"].size, "une ligne sans prestation est écartée"
    assert_equal({ "etat" => "Fissures à reboucher", "teintes" => "2 couleurs" }, d["precisions"])
    assert_equal 1234.5, d["chiffrage"]["total_ttc"]
  end

  test "sans détails ou avec des détails illisibles, la note simple est créée quand même" do
    client = laisser_numero("pas un objet")
    assert_nil client.client_notes.last.donnees
    assert_includes client.client_notes.last.body, "Devis affiché : 1235 € TTC"
  end

  test "la fiche client affiche le projet et le bouton de création" do
    client = laisser_numero
    get admin_client_path(client), headers: AUTH
    assert_response :success
    assert_includes response.body, "Projet saisi sur l'estimateur"
    assert_includes response.body, "Fissures à reboucher"
    assert_includes response.body, "murs 41,03 m²"
    assert_includes response.body, "Créer l&#39;estimation à partir de ce projet"
  end

  test "le bouton crée l'estimation une seule fois, rattachée au client" do
    client = laisser_numero
    note = client.client_notes.last
    assert_difference "Estimation.count", 1 do
      post estimation_admin_client_note_path(client, note), headers: AUTH
    end
    e = Estimation.order(:created_at).last
    assert_redirected_to admin_estimation_path(e)
    assert_equal client, e.client
    assert_equal "manuel", e.origine
    assert_equal "0612345678", e.telephone
    assert_equal "33650", e.code_postal
    assert_equal 1, e.estimation_lines.size
    assert e.estimation_lines.first.poncage_peinture
    assert_includes e.message, "Fissures à reboucher"
    assert_equal e.id, note.reload.donnees["estimation_id"]

    assert_no_difference "Estimation.count" do
      post estimation_admin_client_note_path(client, note), headers: AUTH
    end
    assert_redirected_to admin_estimation_path(e)

    get admin_client_path(client), headers: AUTH
    assert_includes response.body, "Voir l&#39;estimation #{e.reference}"
  end

  test "le formulaire envoyé ensuite reste une estimation distincte et normale" do
    laisser_numero
    post estimation_path, params: { estimation: {
      nom: "Marie Dupont", email: "marie@exemple.fr", telephone: "0612345678", code_postal: "33650",
      type_chantier: "renovation",
      estimation_lines_attributes: { "0" => { piece: "Salon", type_piece: "salon", prestation: "peinture_murs_reno",
                                              gamme: "milieu", mode_saisie: "surface", surface: "41.03" } } } }
    e = Estimation.order(:created_at).last
    assert_equal "web", e.origine
    assert_equal "Marie Dupont", e.client.nom
  end
end
