require "test_helper"

# Le double comptage du CA (fiche Marini affichée 1 510 € au lieu de 755 €,
# juillet 2026) venait d'un chantier saisi À LA FOIS en montant manuel sur la
# fiche client ET porté par un devis terrain sur son estimation.
class CaSansDoubleComptageTest < ActiveSupport::TestCase
  test "le montant manuel est ignoré dès qu'une estimation du client porte un devis chiffré" do
    client = Client.create!(nom: "Marini Test", statut: "gagne", montant_devis_manuel: 755)
    e = estimation_manuelle(nom: "Marini Test", client_id: client.id)
    ligne(e, qte: 10, prix: 75.5) # devis terrain de 755 €
    e.devis_recompute!

    assert_equal 755.to_d, Client.ca_devis(Client.where(id: client.id)),
                 "755 € de devis + 755 € de manuel doivent donner 755 €, pas 1 510 €"
  end

  test "le montant manuel reste compté quand il est seul (cas SCI JMR)" do
    client = Client.create!(nom: "SCI Test", statut: "gagne", montant_devis_manuel: 979.80)
    assert_equal 979.80.to_d, Client.ca_devis(Client.where(id: client.id))
  end
end
