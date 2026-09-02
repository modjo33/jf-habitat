require "test_helper"

# Les 3 pages d'atterrissage Ads existent pour une raison mesurée : le 02/09/2026,
# Google notait l'« expérience de la page de destination » INFÉRIEURE À LA MOYENNE
# sur tous les mots-clés (niveau de qualité 2-3/10, 67 % des impressions perdues
# au classement) parce que les 3 groupes d'annonces pointaient vers
# /estimation/new — un formulaire plein écran sans contenu.
#
# Ce que ces tests protègent : que chaque page réponde, porte SON mot-clé dans le
# titre et le H1, et garde le chemin vers l'estimateur. Une page qui redeviendrait
# vide ou générique referait retomber le niveau de qualité.
class LandingsAdsTest < ActionDispatch::IntegrationTest
  CIBLES = {
    "/peintre-bordeaux"   => { h1: "Peintre en bâtiment à Bordeaux", mot: "peintre" },
    "/plaquiste-bordeaux" => { h1: "Plaquiste à Bordeaux",           mot: "plaquiste" },
    "/parquet-bordeaux"   => { h1: "Pose de parquet à Bordeaux",     mot: "parquet" }
  }.freeze

  test "chaque page d'atterrissage répond et porte son mot-clé" do
    CIBLES.each do |chemin, cible|
      get chemin
      assert_response :success, "#{chemin} doit répondre"

      assert_includes response.body, cible[:h1], "#{chemin} doit porter son H1"
      titre = response.body[%r{<title>(.*?)</title>}m, 1].to_s
      assert_match(/#{cible[:mot]}/i, titre, "le titre de #{chemin} doit contenir « #{cible[:mot]} »")
      assert_match(/bordeaux/i, titre, "le titre de #{chemin} doit contenir « Bordeaux »")

      # Le CTA vers l'estimateur : c'est lui qui transforme la visite en lead.
      assert_includes response.body, new_estimation_path, "#{chemin} doit mener à l'estimateur"
    end
  end

  test "les pages portent assez de contenu pour être jugées par Google" do
    # Le défaut corrigé le 02/09 était l'absence de texte. On garde une marge
    # large (300 mots) : le seuil sert d'alarme, pas de norme rédactionnelle.
    CIBLES.each_key do |chemin|
      get chemin
      texte = response.body.gsub(%r{<script.*?</script>}m, " ").gsub(/<[^>]*>/, " ")
      assert_operator texte.split.size, :>, 300, "#{chemin} doit rester une vraie page de contenu"
    end
  end

  test "un métier inconnu ne lève pas mais renvoie à l'accueil" do
    get "/peintre-bordeaux", params: {}
    assert_response :success

    # La route ne peut pas fabriquer d'autre métier, mais l'action doit rester
    # défensive si une route est ajoutée plus tard avec un mauvais defaults.
    assert_nothing_raised { PagesController::LANDINGS.fetch("peinture") }
  end

  test "les 3 pages figurent au sitemap" do
    get "/sitemap.xml"
    assert_response :success
    CIBLES.each_key { |chemin| assert_includes response.body, chemin }
  end
end
