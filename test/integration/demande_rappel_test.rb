require "test_helper"

# « Être rappelé » (09/09/2026) : sur ~110 clics Ads en 13 jours, 6 devis vus
# en clair et 0 coordonnées laissées, quand le seul chantier signé venait d'un
# appel. Ce test verrouille que le contact le plus court du site crée bien un
# client « à rappeler », prévient Johan, et ne se laisse pas remplir par un robot.
class DemandeRappelTest < ActionDispatch::IntegrationTest
  setup { ActionMailer::Base.deliveries.clear }

  STREAM = { "Accept" => "text/vnd.turbo-stream.html, text/html" }.freeze

  test "un rappel valide crée le client à rappeler aujourd'hui, une note, la balise et le mail" do
    assert_difference [ "Client.count", "ClientNote.count" ], 1 do
      post rappel_path, params: { rappel: { nom: "Marie Dupont", telephone: "06 12 34 56 78",
                                            travaux: "Repeindre un salon", metier: "peinture", page: "/peintre-bordeaux" } },
                        headers: STREAM
    end
    assert_response :success
    assert_includes response.body, "C'est noté"

    c = Client.order(:created_at).last
    assert_equal "0612345678", c.telephone, "le numéro doit être normalisé"
    assert_equal "nouveau", c.statut
    assert_equal Date.current, c.prochaine_action_date, "il doit sortir dans la carte « À relancer » tout de suite"
    assert_includes c.client_notes.last.body, "Repeindre un salon"
    assert_includes c.client_notes.last.body, "/peintre-bordeaux"
    assert_equal 1, EtapeTunnel.where(etape: "rappel", detail: "peinture").count
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_includes ActionMailer::Base.deliveries.last.subject, "0612345678"
  end

  test "sans téléphone, refus explicite en 422 et rien n'est créé" do
    assert_no_difference "Client.count" do
      post rappel_path, params: { rappel: { nom: "Marie", telephone: "" } }, headers: STREAM
    end
    assert_response :unprocessable_entity
    assert_includes response.body, "numéro de téléphone"
  end

  test "un numéro invalide est refusé avec le message du modèle" do
    assert_no_difference "Client.count" do
      post rappel_path, params: { rappel: { nom: "Marie", telephone: "12" } }, headers: STREAM
    end
    assert_response :unprocessable_entity
  end

  test "le pot de miel rempli répond merci sans rien créer ni prévenir" do
    assert_no_difference [ "Client.count", "EtapeTunnel.count" ] do
      post rappel_path, params: { rappel: { nom: "Bot", telephone: "0612345678", site_web: "http://spam" } }, headers: STREAM
    end
    assert_response :success
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  test "un numéro déjà connu enrichit la fiche au lieu de créer un doublon" do
    Client.create!(nom: "Ancien Client", telephone: "0612345678", statut: "perdu")
    assert_no_difference "Client.count" do
      post rappel_path, params: { rappel: { nom: "Ancien", telephone: "06 12 34 56 78" } }, headers: STREAM
    end
    c = Client.find_by(telephone: "0612345678")
    assert_equal "nouveau", c.statut, "un perdu qui rappelle redevient un prospect"
    assert_equal 1, c.client_notes.count
  end

  test "sans JavaScript, le formulaire redirige avec un message" do
    post rappel_path, params: { rappel: { nom: "Marie", telephone: "0612345678" } },
                      headers: { "HTTP_REFERER" => "http://www.example.com/plaquiste-bordeaux" }
    assert_redirected_to "http://www.example.com/plaquiste-bordeaux"
    assert_match(/rappelle/, flash[:notice])
  end

  test "le bandeau d'action est sur les pages publiques, pas sur le wizard, et le panneau partout" do
    get "/peintre-bordeaux"
    assert_includes response.body, 'id="contact-bar"'
    assert_includes response.body, 'id="rappel-panel"'
    assert_includes response.body, 'value="peinture"', "le métier de la page pré-remplit le rappel"

    get "/estimation/new"
    refute_includes response.body, 'id="contact-bar"', "le wizard garde son propre CTA collant"
    assert_includes response.body, 'id="rappel-panel"'
    assert_includes response.body, "être rappelé"
  end
end
