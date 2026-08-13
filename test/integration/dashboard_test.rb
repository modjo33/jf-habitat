require "test_helper"

# Smoke test du dashboard admin : la page doit rendre avec la carte
# « À relancer » alimentée — un lead jamais rappelé et un devis envoyé
# sans réponse doivent y apparaître.
class DashboardTest < ActionDispatch::IntegrationTest
  AUTH = { "Authorization" => ActionController::HttpAuthentication::Basic
             .encode_credentials("admin", "jfhabitat2026") }.freeze

  test "le dashboard rend et liste les relances en attente" do
    vieux_lead = estimation_manuelle(nom: "Lead Oublié", statut: "nouveau")
    vieux_lead.update_columns(created_at: 3.days.ago)

    devis = estimation_manuelle(nom: "Devis Sans Réponse")
    ligne(devis, qte: 10, prix: 100)
    devis.devis_recompute!
    devis.update_columns(devis_envoye_at: 10.days.ago)

    get admin_root_path, headers: AUTH
    assert_response :success
    assert_includes response.body, "À relancer"
    assert_includes response.body, "Lead Oublié"
    assert_includes response.body, "Devis Sans Réponse"
  end

  test "sans relance en attente, la carte disparaît" do
    get admin_root_path, headers: AUTH
    assert_response :success
    assert_not_includes response.body, "À relancer"
  end
end
