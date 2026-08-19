require "test_helper"

# Un clic Google Ads depuis iOS peut porter un gbraid/wbraid à la place du
# gclid : il doit être capturé à l'atterrissage, marquer la visite « ads »
# dans le tunnel, et se retrouver sur l'estimation soumise.
class SourceGbraidTest < ActionDispatch::IntegrationTest
  setup do
    Tarif.create!(prestation: "peinture_murs_reno", gamme: "milieu", prix_m2: 22, unite: "m2")
  end

  test "un atterrissage avec gbraid attribue le lead à Google Ads" do
    get new_estimation_path(gbraid: "TestGbraid123")

    post estimation_path, params: {
      estimation: {
        nom: "Testeur", email: "gbraid@test.fr", telephone: "0612345678",
        code_postal: "33640", ville: "Créon", type_chantier: "renovation",
        estimation_lines_attributes: {
          "0" => { piece: "Salon", type_piece: "salon", mode_saisie: "surface",
                   prestation: "peinture_murs_reno", gamme: "milieu", surface: "20" }
        }
      }
    }

    estimation = Estimation.order(:id).last
    assert_equal "TestGbraid123", estimation.gbraid
    assert estimation.issu_de_google_ads?
    assert_equal "Google Ads", estimation.source_label
    assert_equal "ads", EtapeTunnel.where(etape: "soumis").order(:id).last&.source
  end
end
