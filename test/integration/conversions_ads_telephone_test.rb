require "test_helper"

# Numéro laissé depuis un clic Google Ads (09/11/2026) : depuis le téléphone
# avant le prix, c'est le contact le plus fréquent, mais il ne gardait pas le
# gclid. Google voyait 101 clics et zéro lead.
class ConversionsAdsTelephoneTest < ActionDispatch::IntegrationTest
  AUTH = { "Authorization" => ActionController::HttpAuthentication::Basic
             .encode_credentials("admin", "jfhabitat2026") }.freeze

  setup do
    Tarif.create!(prestation: "peinture_murs_reno", gamme: "milieu", prix_m2: 22, unite: "m2")
  end

  def laisser_numero(telephone = "0612345678")
    post telephone_estimation_path, params: { telephone: telephone, total: "1804", projet: "Salon" },
                                    headers: { "Accept" => "application/json" }, as: :json
    assert_response :no_content
    Client.find_by!(telephone: telephone).client_notes.last
  end

  # Seuls le clic et les dates comptent ici : les pièces n'ont pas d'intérêt.
  def estimation_ads(**attrs)
    Estimation.new(nom: "Testeur", email: "t@test.fr", code_postal: "33640",
                   reference: "TEST-#{attrs[:gclid]}", **attrs)
              .tap { |e| e.save!(validate: false) }
  end

  test "le numéro laissé après un clic garde le gclid et part dans l'export" do
    get new_estimation_path(gclid: "ClicTel123")
    note = laisser_numero

    assert_equal "ClicTel123", note.gclid
    assert_includes ConversionsAds.a_exporter("lead"), note
    csv = ConversionsAds.csv("lead")
    assert_includes csv, "ClicTel123,Devis demandé (import),"
    assert_includes csv, ",360.80,EUR", "20 % du devis vu"
  end

  test "la demande de rappel après un clic part aussi, au plancher" do
    get root_path(gclid: "ClicRappel")
    post rappel_path, params: { rappel: { nom: "Léa", telephone: "0698765432", travaux: "Peinture" } }

    note = Client.find_by!(telephone: "0698765432").client_notes.last
    assert_equal "ClicRappel", note.gclid
    assert_equal ConversionsAds::VALEUR_LEAD_MINIMALE, ConversionsAds.valeur(note, "lead")
  end

  test "sans clic publicitaire, rien n'est exporté" do
    note = laisser_numero
    assert_nil note.gclid
    assert_empty ConversionsAds.a_exporter("lead")
  end

  test "numéro puis formulaire depuis le même clic : un seul lead, marqué partout" do
    get new_estimation_path(gclid: "ClicDouble")
    note = laisser_numero
    estimation_ads(gclid: "ClicDouble", telephone: "0612345678")

    assert_equal [ note ], ConversionsAds.a_exporter("lead"), "le premier contact est gardé"

    post admin_marquer_conversions_ads_path(type: "lead"), headers: AUTH
    assert note.reload.ads_export_lead_at
    assert Estimation.find_by(gclid: "ClicDouble").ads_export_lead_at
    assert_empty ConversionsAds.a_exporter("lead")
  end

  test "un numéro laissé après l'import du même clic ne repart pas" do
    estimation_ads(gclid: "ClicVieux", telephone: "0611111111", ads_export_lead_at: 1.day.ago)
    get new_estimation_path(gclid: "ClicVieux")
    laisser_numero

    assert_empty ConversionsAds.a_exporter("lead")
  end

  test "l'écran d'export liste le numéro avec un lien vers la fiche" do
    get new_estimation_path(gclid: "ClicEcran")
    note = laisser_numero

    get admin_conversions_ads_path, headers: AUTH
    assert_response :success
    assert_includes response.body, admin_client_path(note.client)
    assert_includes response.body, note.reference
  end

  test "les ventes restent limitées aux devis signés" do
    get new_estimation_path(gclid: "ClicVente")
    laisser_numero
    assert_empty ConversionsAds.a_exporter("vente")
  end
end
