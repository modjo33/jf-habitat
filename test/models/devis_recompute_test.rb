require "test_helper"

# Le moteur de calcul du devis : chaque euro affiché au client sort d'ici.
# Un bug (double comptage du CA, juillet 2026) a déjà montré ce que coûte
# un total faux — ces tests verrouillent les règles au centime.
class DevisRecomputeTest < ActiveSupport::TestCase
  test "lignes m² et forfait : total = somme exacte des lignes" do
    e = estimation_manuelle
    ligne(e, qte: 7.88, prix: 23)          # 181,24
    ligne(e, qte: 10.38, prix: 8)          #  83,04
    ligne(e, libelle: "Protection", unite: "forfait", prix: 90, qte: nil) # 90 (forfait : la quantité est ignorée)
    e.devis_recompute!

    assert_equal 354.28.to_d, e.reload.devis_total_brut
    assert_equal 354.28.to_d, e.devis_total
  end

  test "un forfait ignore la quantité" do
    e = estimation_manuelle
    l = ligne(e, unite: "forfait", prix: 150, qte: 12)
    assert_equal 150.to_d, l.total
  end

  test "remise en pourcentage sur le sous-total complet (travaux + extras)" do
    e = estimation_manuelle
    ligne(e, qte: 100, prix: 10)                                  # 1 000
    e.update_columns(devis_trajet_prix_jour: 30, devis_trajet_jours: 2,
                     devis_consommables: 40,
                     devis_remise_type: "pourcentage", devis_remise_valeur: 10)
    e.devis_recompute!
    # sous-total = 1000 + 60 + 40 = 1100 ; remise 10 % → 990
    assert_equal 990.to_d, e.reload.devis_total
  end

  test "l'échéancier calcule le solde comme le reste du total" do
    e = estimation_manuelle
    ligne(e, qte: 100, prix: 49.72) # 4 972,00 → proche du devis Frassatti
    e.update_columns(devis_echeances: [
      { "libelle" => "Acompte à la signature", "pct" => 30 },
      { "libelle" => "Solde à la fin du chantier", "pct" => nil }
    ])
    e.devis_recompute!
    rows = e.reload.devis_echeances_list

    assert_equal 1491.60.to_d, rows[0][:montant]
    assert_equal (4972.00 - 1491.60).to_d, rows[1][:montant]
    assert_equal e.devis_total, rows.sum { |r| r[:montant] }
  end

  test "l'échéancier par défaut se pose sur un devis vierge, jamais sur un devis envoyé" do
    e = estimation_manuelle
    e.appliquer_echeancier_defaut!
    assert e.reload.devis_echeancier?, "le défaut doit s'appliquer à un devis sans échéancier"

    envoye = estimation_manuelle(nom: "Déjà envoyé")
    envoye.update_column(:devis_envoye_at, Time.current)
    envoye.appliquer_echeancier_defaut!
    assert_not envoye.reload.devis_echeancier?, "un devis déjà envoyé ne doit pas être modifié"
  end
end
