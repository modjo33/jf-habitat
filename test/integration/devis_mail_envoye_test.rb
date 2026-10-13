require "test_helper"

# Indicateur « mail envoyé ou pas » : en octobre 2026, la fiche client
# affichait « Devis prêt à envoyer » sur des devis déjà partis (Vinet, Kebir).
class DevisMailEnvoyeTest < ActionDispatch::IntegrationTest
  AUTH = { "Authorization" => ActionController::HttpAuthentication::Basic
             .encode_credentials("admin", "jfhabitat2026") }.freeze

  setup do
    @client = Client.create!(nom: "Client Mail", statut: "contacte", email: "client@example.com")
    @e = estimation_manuelle(email: "client@example.com", client: @client)
    ligne(@e, qte: 10, prix: 20)
    @e.devis_recompute!
    @e.create_devis_document!(data: "%PDF-1.4\ndevis\n%%EOF")
  end

  test "devis jamais envoyé : indiqué partout, bouton Envoyer" do
    refute @e.reload.devis_envoye?
    [admin_client_path(@client), admin_estimation_path(@e), admin_devis_path].each do |chemin|
      get chemin, headers: AUTH
      assert_response :success
      assert_includes response.body, "Mail pas encore envoyé", chemin
    end
    get admin_client_path(@client), headers: AUTH
    refute_includes response.body, "Devis prêt à envoyer"
    assert_includes response.body, "Envoyer au client"
  end

  test "l'envoi par l'appli date le mail et l'affiche avec Renvoyer" do
    post devis_envoyer_admin_estimation_path(@e), headers: AUTH, params: { message: "Bonjour" }
    assert @e.reload.devis_envoye?

    get admin_client_path(@client), headers: AUTH
    assert_includes response.body, "Mail envoyé le #{I18n.l(@e.devis_envoye_at, format: '%d/%m à %H:%M')}"
    assert_includes response.body, "Renvoyer"
    refute_includes response.body, "PDF modifié depuis l'envoi"

    get devis_envoi_admin_estimation_path(@e), headers: AUTH
    assert_includes response.body, "déjà été envoyé"
  end

  test "PDF régénéré après l'envoi : avertissement" do
    @e.update_column(:devis_envoye_at, 2.days.ago)
    @e.devis_document.update!(data: "%PDF-1.4\nv2\n%%EOF")
    assert Estimation.find(@e.id).devis_modifie_apres_envoi?

    get admin_estimation_path(@e), headers: AUTH
    assert_includes response.body, "PDF modifié depuis l'envoi"
  end
end
