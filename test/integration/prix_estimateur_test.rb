require "test_helper"

# Lead Bègles du 13/10/2026 : 9 547 € pour un salon et une salle de bain.
# L'aperçu ajoutait 10 % de TVA jamais facturée, la Gironde prenait +5 %, et
# le prix vu à l'écran ignorait le ponçage pourtant facturé dans le devis.
class PrixEstimateurTest < ActionDispatch::IntegrationTest
  setup do
    Tarif.create!(prestation: "peinture_murs_reno", gamme: "milieu", prix_m2: 22, unite: "m2")
    Tarif.create!(prestation: "poncage_peinture", gamme: "milieu", prix_m2: 4, unite: "m2")
  end

  def preview(code_postal: "33130", poncage: "0")
    post "/estimation/preview.json", params: {
      code_postal: code_postal,
      lines: [ { prestation: "peinture_murs_reno", gamme: "milieu", type_piece: "salon",
                 mode_saisie: "surface", surface: "10", poncage_peinture: poncage } ]
    }
    JSON.parse(response.body)
  end

  test "pas de TVA ni de majoration en Gironde : 10 m² × 22 € = 220 €" do
    assert_equal 220.0, preview["total_ttc"].to_f
  end

  test "le ponçage coché entre dans le prix affiché, comme dans le devis enregistré" do
    assert_equal 260.0, preview(poncage: "1")["total_ttc"].to_f
  end

  test "le prix affiché égale le total enregistré du lead" do
    affiche = preview(poncage: "1")["total_ttc"].to_f
    post estimation_path, params: { estimation: {
      nom: "Client Prix", email: "prix@example.com", telephone: "0612345678",
      code_postal: "33130", ville: "Bègles", type_chantier: "renovation",
      estimation_lines_attributes: { "0" => { piece: "Salon", type_piece: "salon", mode_saisie: "surface",
        prestation: "peinture_murs_reno", gamme: "milieu", surface: "10", poncage_peinture: "1" } } } }
    assert_equal affiche, Estimation.order(:created_at).last.total_ttc.to_f
  end

  test "les autres grandes métropoles gardent leur coefficient" do
    assert_equal 231.0, preview(code_postal: "69001")["total_ttc"].to_f
  end
end
