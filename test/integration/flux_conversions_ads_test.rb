require "test_helper"

# Flux lu par la feuille Google reliée à Google Ads (09/11/2026) : plus de
# CSV à recoller à la main chaque semaine.
class FluxConversionsAdsTest < ActionDispatch::IntegrationTest
  JETON = "j" * 40

  setup do
    @jeton_avant = ENV["CONVERSIONS_ADS_JETON"]
    ENV["CONVERSIONS_ADS_JETON"] = JETON
    Tarif.create!(prestation: "peinture_murs_reno", gamme: "milieu", prix_m2: 22, unite: "m2")
  end

  teardown { ENV["CONVERSIONS_ADS_JETON"] = @jeton_avant }

  def laisser_numero(gclid, telephone)
    get new_estimation_path(gclid: gclid)
    post telephone_estimation_path, params: { telephone: telephone, total: "1000" },
                                    headers: { "Accept" => "application/json" }, as: :json
    reset!
  end

  test "le flux contient tous les leads de la fenêtre, déjà envoyés ou non" do
    laisser_numero("ClicA", "0611111111")
    laisser_numero("ClicB", "0622222222")
    ClientNote.where(gclid: "ClicA").update_all(ads_export_lead_at: 1.day.ago)

    get flux_conversions_ads_path(jeton: JETON)
    assert_response :success
    assert_equal "text/csv", response.media_type
    lignes = response.body.lines
    assert_equal "Google Click ID,Conversion Name,Conversion Time,Conversion Value,Conversion Currency\n", lignes.first
    assert_includes response.body, "ClicA,Devis demandé (import),"
    assert_includes response.body, "ClicB,Devis demandé (import),"
    assert_equal 3, lignes.size
  end

  test "un mauvais jeton ou un jeton absent répond 404" do
    get flux_conversions_ads_path(jeton: "mauvais")
    assert_response :not_found

    ENV["CONVERSIONS_ADS_JETON"] = ""
    get flux_conversions_ads_path(jeton: "x")
    assert_response :not_found
  end

  test "un jeton trop court est refusé même s'il correspond" do
    ENV["CONVERSIONS_ADS_JETON"] = "court"
    get flux_conversions_ads_path(jeton: "court")
    assert_response :not_found
  end

  test "le robot de Google n'est pas refusé comme vieux navigateur et ne compte pas dans le tunnel" do
    assert_no_difference "EtapeTunnel.count" do
      get flux_conversions_ads_path(jeton: JETON), headers: { "User-Agent" => "Mozilla/5.0 (compatible; GoogleDocs; apps-spreadsheets)" }
    end
    assert_response :success
  end
end
