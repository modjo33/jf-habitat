require "test_helper"

# Le 02/09/2026 les annonces ont été redirigées vers les pages métier. Du 03 au
# 09/09, /admin/tunnel affichait un entonnoir quasi vide alors que Google
# facturait ~58 clics par semaine : les visiteurs s'arrêtaient sur une page
# que la mesure ne voyait pas. Ces tests garantissent que la marche est comptée.
class PagesMetierTunnelTest < ActionDispatch::IntegrationTest
  test "une page métier émet la balise atterrissage avec son métier" do
    assert_difference -> { EtapeTunnel.where(etape: "atterrissage", detail: "placo").count }, 1 do
      get "/plaquiste-bordeaux"
    end
    assert_response :success
  end

  test "un robot n'est pas compté" do
    assert_no_difference -> { EtapeTunnel.count } do
      get "/peintre-bordeaux", headers: { "User-Agent" => "Googlebot/2.1" }
    end
  end

  test "la même visite qui ouvre ensuite l'estimateur est comptée comme passée" do
    get "/peintre-bordeaux"
    get "/estimation/new"
    pm = EtapeTunnel.pages_metier(debut: Date.current, fin: Date.current)
    assert_equal 1, pm[:total]
    assert_equal 1, pm[:vers_estimateur]
    assert_equal [ [ "peinture", 1 ] ], pm[:par_metier]
  end

  test "la balise navigateur page_lue compte les visiteurs réels, un rappel compte comme une action" do
    get "/plaquiste-bordeaux"
    post suivi_tunnel_path, params: { etape: "page_lue", detail: "placo" }, as: :json
    post suivi_tunnel_path, params: { etape: "page_lue", detail: "placo" }, as: :json
    post suivi_tunnel_path, params: { etape: "rappel", detail: "placo" }, as: :json
    pm = EtapeTunnel.pages_metier(debut: Date.current, fin: Date.current)
    assert_equal 1, pm[:total]
    assert_equal 1, pm[:reels], "une visite = un visiteur réel, même balisée deux fois"
    assert_equal "placo", EtapeTunnel.find_by(etape: "page_lue").detail, "le métier de la page lue doit être conservé"
    assert_equal 1, pm[:rappels]
    assert_equal 0, pm[:vers_estimateur]
  end

  test "la page métier porte l'attribut qui déclenche la balise navigateur" do
    get "/peintre-bordeaux"
    assert_includes response.body, 'data-page-metier="peinture"'
  end

  test "la carte apparaît dans l'admin même sans arrivée sur l'estimateur" do
    get "/parquet-bordeaux"
    get admin_tunnel_path, headers: admin_headers
    assert_response :success
    assert_includes response.body, "Pages métier"
    assert_includes response.body, "Parquet 1"
    assert_includes response.body, "mesure navigateur depuis le 14/09", "sans balise page_lue, la carte dit qu'elle compte des chargements"
  end

  test "avec des visiteurs réels, les taux sont rapportés à eux et non aux chargements" do
    3.times do
      get "/peintre-bordeaux"
      reset!
    end
    get "/peintre-bordeaux"
    post suivi_tunnel_path, params: { etape: "page_lue", detail: "peinture" }, as: :json
    get "/estimation/new"
    get admin_tunnel_path, headers: admin_headers
    assert_response :success
    assert_includes response.body, "sur 4 chargements, robots inclus"
    assert_includes response.body, "100 % des visiteurs"
  end

  private

  def admin_headers
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(
      ENV.fetch("ADMIN_USER", "admin"), ENV.fetch("ADMIN_PASSWORD", "jfhabitat2026")) }
  end
end
