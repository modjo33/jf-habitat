require "test_helper"

# La liste des appels sert à rapprocher chaque tap sur le bouton d'appel du
# journal d'appels de Johan : heure, page d'arrivée, ce que le visiteur a vu.
class ListeAppelsTest < ActiveSupport::TestCase
  def baliser(visite, etape, detail: nil, at: Time.current)
    EtapeTunnel.create!(visite: visite, etape: etape, detail: detail, source: "ads", appareil: "mobile", created_at: at)
  end

  test "un appel depuis une page métier après un devis vu porte tout son contexte" do
    baliser("v1", "atterrissage", detail: "placo", at: 3.minutes.ago)
    baliser("v1", "arrivee", at: 2.minutes.ago)
    baliser("v1", "devis_vu", detail: "1487", at: 1.minute.ago)
    baliser("v1", "appel")

    appel = EtapeTunnel.liste_appels(debut: Date.current, fin: Date.current).sole
    assert_equal "placo", appel[:page]
    assert appel[:estimateur]
    assert_equal "1487", appel[:devis_vu]
    refute appel[:tel_donne]
  end

  test "un appel sans page métier ni estimateur sort en autre page, dans l'ordre chronologique" do
    baliser("v2", "appel", at: 1.minute.ago)
    baliser("v3", "arrivee", at: 2.minutes.ago)
    baliser("v3", "appel")

    appels = EtapeTunnel.liste_appels(debut: Date.current, fin: Date.current)
    assert_equal [ "autre page", "estimateur" ], appels.map { |a| a[:page] }
  end
end
