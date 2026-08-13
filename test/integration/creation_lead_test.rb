require "test_helper"

# Le POST /estimation est LE geste qui rapporte : onze jours sans lead en
# août parce que le bouton final ne soumettait plus (côté client). Côté
# serveur, ce test verrouille qu'une soumission valide crée le lead, part
# en mails, et qu'une invalide répond 422 — jamais un échec silencieux.
class CreationLeadTest < ActionDispatch::IntegrationTest
  setup do
    Tarif.create!(prestation: "peinture_murs_reno", gamme: "milieu", prix_m2: 22, unite: "m2")
    ActionMailer::Base.deliveries.clear
  end

  def params_valides
    { estimation: {
      nom: "Client Wizard", email: "wizard@example.com", telephone: "0612345678",
      code_postal: "33640", ville: "Ayguemorte-les-Graves", type_chantier: "renovation",
      estimation_lines_attributes: {
        "0" => { piece: "Salon", type_piece: "salon", mode_saisie: "surface",
                 prestation: "peinture_murs_reno", gamme: "milieu", surface: "20" }
      }
    } }
  end

  test "une soumission valide crée le lead, le chiffre, et envoie les deux mails" do
    assert_difference "Estimation.count", 1 do
      post estimation_path, params: params_valides
    end
    e = Estimation.order(:created_at).last

    assert_redirected_to estimation_path(reference: e.reference)
    assert_operator e.total_ttc, :>, 0, "le devis doit être chiffré (tarif présent)"
    assert_equal 2, ActionMailer::Base.deliveries.size,
                 "notification Johan + confirmation client doivent partir en deliver_now"
  end

  test "un téléphone invalide répond 422, jamais un succès mensonger" do
    p = params_valides
    p[:estimation][:telephone] = "12"
    assert_no_difference "Estimation.count" do
      post estimation_path, params: p
    end
    assert_response :unprocessable_entity
  end

  test "un mail qui explose ne fait pas échouer la création du lead" do
    LeadMailer.singleton_class.define_method(:nouveau_lead) { |*| raise "SMTP en panne" }
    assert_difference "Estimation.count", 1 do
      post estimation_path, params: params_valides
    end
    assert_response :redirect, "le visiteur doit voir son devis même si le mail échoue"
  ensure
    LeadMailer.singleton_class.remove_method(:nouveau_lead)
  end
end
