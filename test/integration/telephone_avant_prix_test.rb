require "test_helper"

# Téléphone AVANT le prix (30/09/2026) : du 25 au 30/09, 4 visiteurs ont vu
# leur devis en clair et aucun n'a laissé ses coordonnées. Le numéro est
# désormais demandé seul, et il doit créer un contact « à rappeler » tout de
# suite, même si le visiteur repart sans envoyer le formulaire.
class TelephoneAvantPrixTest < ActionDispatch::IntegrationTest
  setup { ActionMailer::Base.deliveries.clear }

  JSON_HEADERS = { "Accept" => "application/json" }.freeze

  test "un numéro valide crée le contact à rappeler, la note, la balise et le mail" do
    assert_difference [ "Client.count", "ClientNote.count" ], 1 do
      post telephone_estimation_path, params: { telephone: "06 12 34 56 78", total: "10115",
                                                projet: "Salon · Peinture des murs · Milieu de gamme" },
                                      headers: JSON_HEADERS, as: :json
    end
    assert_response :no_content

    c = Client.order(:created_at).last
    assert_equal "0612345678", c.telephone
    assert_equal Client::NOM_PROVISOIRE, c.nom
    assert_equal "nouveau", c.statut
    assert_equal Date.current, c.prochaine_action_date
    assert_includes c.prochaine_action, "10115 €"
    assert_includes c.client_notes.last.body, "Salon · Peinture des murs"
    assert_equal 1, EtapeTunnel.where(etape: "tel_donne", detail: "10115").count
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_includes ActionMailer::Base.deliveries.last.subject, "0612345678"
  end

  test "un numéro mal formé est refusé en 422, rien n'est créé" do
    assert_no_difference [ "Client.count", "EtapeTunnel.count" ] do
      post telephone_estimation_path, params: { telephone: "12345" }, headers: JSON_HEADERS, as: :json
    end
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["erreur"], "10 chiffres"
  end

  test "le pot de miel répond OK sans rien créer ni prévenir" do
    assert_no_difference [ "Client.count", "EtapeTunnel.count" ] do
      post telephone_estimation_path, params: { telephone: "0612345678", site_web: "spam" },
                                      headers: JSON_HEADERS, as: :json
    end
    assert_response :no_content
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  test "un numéro déjà connu enrichit la fiche existante" do
    ancien = Client.create!(nom: "Ancien Client", telephone: "0612345678", statut: "perdu")
    assert_no_difference "Client.count" do
      post telephone_estimation_path, params: { telephone: "0612345678" }, headers: JSON_HEADERS, as: :json
    end
    ancien.reload
    assert_equal "Ancien Client", ancien.nom, "le vrai nom ne doit pas être écrasé"
    assert_equal "nouveau", ancien.statut
  end

  test "le formulaire envoyé ensuite complète la même fiche au lieu d'un doublon" do
    Client.create!(nom: Client::NOM_PROVISOIRE, telephone: "0612345678", statut: "nouveau")
    estimation = Estimation.new(nom: "Marie Dupont", email: "Marie@Exemple.fr", telephone: "0612345678")
    assert_no_difference "Client.count" do
      Client.upsert_from_estimation(estimation)
    end
    c = Client.find_by(telephone: "0612345678")
    assert_equal "Marie Dupont", c.nom
    assert_equal "marie@exemple.fr", c.email
  end
end
