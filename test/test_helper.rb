ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Pas de fixtures : chaque test construit exactement les données dont il a
# besoin. Cette suite couvre EN PRIORITÉ ce qui a réellement cassé en prod
# (bouton final muet, totaux de devis, PDF, CA compté deux fois) — c'est une
# suite de non-régression, pas une couverture exhaustive.
module TestFabrique
  # Estimation « manuelle » (origine admin) : dispense des validations du
  # tunnel public, parfaite pour tester devis/PDF sans bruit.
  def estimation_manuelle(attrs = {})
    Estimation.create!({ origine: "manuel", statut: "contacte", devis_actif: true,
                         tva_taux: 0, nom: "Client Test" }.merge(attrs))
  end

  def ligne(estimation, section: "Travaux", libelle: "Peinture murs", qte: 10,
            unite: "m2", prix: 22, description: nil)
    estimation.devis_lignes.create!(section: section, libelle: libelle, description: description,
                                    quantite: qte, unite: unite, prix_unitaire: prix)
  end
end

module ActiveSupport
  class TestCase
    include TestFabrique
  end
end
