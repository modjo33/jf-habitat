namespace :tarifs do
  desc "Crée les nouveaux tarifs (plafond neuf + suppléments) sans écraser les prix existants"
  task add_new: :environment do
    nouveaux = [
      # Peinture plafond neuf (3 gammes)
      { prestation: "peinture_plafond_neuf", gamme: "entree", prix_m2: 20, description: "Peinture plafond blanche sur support neuf" },
      { prestation: "peinture_plafond_neuf", gamme: "milieu", prix_m2: 26, description: "Peinture plafond mate, sous-couche incluse" },
      { prestation: "peinture_plafond_neuf", gamme: "haut",   prix_m2: 36, description: "Peinture plafond premium, finition soignée" },
      # Bandes & enduit (finition placo) — prestation à part
      { prestation: "placo_bandes_enduit", gamme: "entree", prix_m2: 10, description: "Bandes + 2 passes d'enduit, prêt à peindre" },
      { prestation: "placo_bandes_enduit", gamme: "milieu", prix_m2: 14, description: "Bandes + 3 passes d'enduit, ponçage, surface lisse" },
      { prestation: "placo_bandes_enduit", gamme: "haut",   prix_m2: 20, description: "Finition haute qualité, ratissage complet, prêt à décorer" },
      # Suppléments (une seule ligne, gamme "milieu" par convention)
      { prestation: "poncage",           gamme: "milieu", prix_m2: 22, description: "Ponçage + vitrification d'un parquet existant (par m²)" },
      { prestation: "poncage_peinture",  gamme: "milieu", prix_m2: 8,  description: "Ponçage / préparation des supports avant peinture (par m²)" },
      { prestation: "depose_evacuation", gamme: "milieu", prix_m2: 12, description: "Dépose et évacuation de l'ancien revêtement (par m²)" }
    ]

    nouveaux.each do |attrs|
      t = Tarif.find_or_create_by(prestation: attrs[:prestation], gamme: attrs[:gamme]) do |rec|
        rec.prix_m2     = attrs[:prix_m2]
        rec.description = attrs[:description]
        rec.unite       = "m2"
        rec.actif       = true
      end
      puts(t.previously_new_record? ? "✓ créé #{attrs[:prestation]}/#{attrs[:gamme]}" : "= existe déjà #{attrs[:prestation]}/#{attrs[:gamme]}")
    end
    puts "TARIFS_ADD_NEW_DONE"
  end
end
