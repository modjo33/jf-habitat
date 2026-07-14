namespace :prestations do
  desc "Remplit la bibliothèque de prestations avec un jeu de base (idempotent)"
  task seed: :environment do
    data = [
      # Protection
      ["protection", "Protection des sols, mobilier et menuiseries", "forfait", 0,
       "Protection des sols, du mobilier et des menuiseries avant travaux (bâches, adhésif de masquage)."],
      # Préparation
      ["preparation", "Ponçage / préparation", "m2", 4,
       "Ponçage léger et dépoussiérage des supports pour préparer la mise en peinture."],
      ["preparation", "Ponçage complet", "m2", 8,
       "Ponçage complet des supports, dépoussiérage."],
      ["preparation", "Reprises d'enduit ponctuelles", "forfait", 0,
       "Rebouchage et reprises d'enduit sur les défauts ponctuels (fissures fines, trous, éclats), ponçage des reprises."],
      ["preparation", "Enduit de lissage", "m2", 10,
       "Application d'un enduit de lissage pour une surface parfaitement plane."],
      ["preparation", "Sous-couche d'impression opacifiante", "m2", 8,
       "Application d'une sous-couche opacifiante pour masquer l'ancienne teinte avant la mise en peinture."],
      # Peinture
      ["peinture", "Peinture murs — 2 couches", "m2", 22,
       "Application de deux couches de peinture sur les murs."],
      ["peinture", "Peinture plafond — 2 couches", "m2", 25,
       "Application de deux couches de peinture spéciale plafond, finition mate."],
      ["peinture", "Peinture boiseries / menuiseries", "ml", 15,
       "Mise en peinture des boiseries et menuiseries (plinthes, portes, encadrements)."],
      # Revêtement
      ["revetement", "Pose parquet stratifié", "m2", 25,
       "Fourniture et pose d'un parquet stratifié, plinthes comprises."],
      # Divers
      ["divers", "Déplacement / trajet", "forfait", 0, "Frais de déplacement sur le chantier."],
      ["divers", "Consommables et petit matériel", "forfait", 0, "Consommables et petit matériel de chantier."]
    ]

    created = 0
    data.each_with_index do |(cat, nom, unite, prix, desc), i|
      p = Prestation.find_or_initialize_by(nom: nom)
      p.categorie = cat; p.unite = unite; p.description = desc
      p.prix = prix if p.new_record?
      p.position = i; p.actif = true
      created += 1 if p.new_record?
      p.save!
    end
    puts "Bibliothèque : #{Prestation.count} prestations (#{created} nouvelles)."
    puts "PRESTATIONS_SEED_DONE"
  end
end
