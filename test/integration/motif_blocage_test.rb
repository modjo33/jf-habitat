require "test_helper"

# Le motif d'un `envoi_bloque` dit QUEL champ arrête les visiteurs refusés au
# dernier écran — sans lui, un téléphone qui fait fuir et une dimension
# aberrante ont la même signature. Le motif ne doit exister QUE pour
# `envoi_bloque` : sur les autres étapes, ce serait du bruit stocké pour rien.
class MotifBlocageTest < ActionDispatch::IntegrationTest
  test "le motif du refus est stocké avec envoi_bloque et ressort groupé" do
    post suivi_tunnel_path, params: { etape: "envoi_bloque", detail: "Merci d'indiquer votre téléphone." }, as: :json
    assert_response :no_content

    ligne = EtapeTunnel.find_by(etape: "envoi_bloque")
    assert_equal "Merci d'indiquer votre téléphone.", ligne.detail

    motifs = EtapeTunnel.motifs_blocage(debut: Date.current, fin: Date.current)
    assert_equal [ [ "Merci d'indiquer votre téléphone.", 1 ] ], motifs
  end

  test "la fourchette vue est stockée avec son montant" do
    post suivi_tunnel_path, params: { etape: "fourchette_vue", detail: "1100-1600" }, as: :json
    assert_equal "1100-1600", EtapeTunnel.find_by(etape: "fourchette_vue").detail
  end

  # Renversement du 28/08/2026 : le devis s'affiche en clair, la balise porte
  # le total vu — croisée avec les non-envois, elle dit si le prix fait fuir.
  test "le devis vu est stocké avec son total" do
    post suivi_tunnel_path, params: { etape: "devis_vu", detail: "5648" }, as: :json
    assert_equal "5648", EtapeTunnel.find_by(etape: "devis_vu").detail
  end

  test "le detail est ignoré hors envoi_bloque et tronqué à 120 caractères" do
    post suivi_tunnel_path, params: { etape: "contact", detail: "ne doit pas être stocké" }, as: :json
    assert_nil EtapeTunnel.find_by(etape: "contact").detail

    post suivi_tunnel_path, params: { etape: "envoi_bloque", detail: "x" * 300 }, as: :json
    assert_equal 120, EtapeTunnel.find_by(etape: "envoi_bloque").detail.length
  end

  test "un envoi_bloque sans motif ressort en « motif non enregistré »" do
    post suivi_tunnel_path, params: { etape: "envoi_bloque" }, as: :json

    motifs = EtapeTunnel.motifs_blocage(debut: Date.current, fin: Date.current)
    assert_equal [ [ "motif non enregistré", 1 ] ], motifs
  end
end
