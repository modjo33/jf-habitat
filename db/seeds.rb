# Tarifs moyens marché France 2026 (TTC, fourniture + pose, €/m²)
# ⚠️ À ajuster via l'admin par Johan selon ses tarifs réels

TARIFS = [
  # Peinture murs rénovation (préparation, rebouchage, 2 couches)
  { prestation: "peinture_murs_reno", gamme: "entree", prix_m2: 22, description: "Peinture acrylique standard, 2 couches" },
  { prestation: "peinture_murs_reno", gamme: "milieu", prix_m2: 30, description: "Peinture acrylique mate/satinée, rebouchage inclus" },
  { prestation: "peinture_murs_reno", gamme: "haut",   prix_m2: 42, description: "Peinture premium (Farrow & Ball, Little Greene…), préparation soignée" },

  # Peinture murs neuf
  { prestation: "peinture_murs_neuf", gamme: "entree", prix_m2: 18, description: "Peinture acrylique standard sur placo neuf" },
  { prestation: "peinture_murs_neuf", gamme: "milieu", prix_m2: 24, description: "Peinture acrylique satinée, sous-couche incluse" },
  { prestation: "peinture_murs_neuf", gamme: "haut",   prix_m2: 32, description: "Peinture premium, finition soignée" },

  # Peinture plafond
  { prestation: "peinture_plafond", gamme: "entree", prix_m2: 25, description: "Peinture plafond blanche standard" },
  { prestation: "peinture_plafond", gamme: "milieu", prix_m2: 32, description: "Peinture plafond mate, rebouchage inclus" },
  { prestation: "peinture_plafond", gamme: "haut",   prix_m2: 45, description: "Peinture plafond premium, préparation complète" },

  # Placo cloison
  { prestation: "placo_cloison", gamme: "entree", prix_m2: 50, description: "BA13 standard, ossature métallique" },
  { prestation: "placo_cloison", gamme: "milieu", prix_m2: 65, description: "BA13 hydrofuge ou phonique, finitions soignées" },
  { prestation: "placo_cloison", gamme: "haut",   prix_m2: 85, description: "Placo haute performance (phonique + hydrofuge), isolation incluse" },

  # Placo plafond
  { prestation: "placo_plafond", gamme: "entree", prix_m2: 45, description: "Plafond BA13 standard suspendu" },
  { prestation: "placo_plafond", gamme: "milieu", prix_m2: 58, description: "Plafond BA13 phonique avec isolation" },
  { prestation: "placo_plafond", gamme: "haut",   prix_m2: 78, description: "Plafond acoustique premium, isolation renforcée" },

  # Parquet stratifié
  { prestation: "parquet_stratifie", gamme: "entree", prix_m2: 30, description: "Stratifié AC3, pose flottante" },
  { prestation: "parquet_stratifie", gamme: "milieu", prix_m2: 45, description: "Stratifié AC4, sous-couche phonique incluse" },
  { prestation: "parquet_stratifie", gamme: "haut",   prix_m2: 60, description: "Stratifié AC5 premium, grande lame" },

  # Parquet contrecollé
  { prestation: "parquet_contrecolle", gamme: "entree", prix_m2: 65,  description: "Contrecollé chêne 10mm, pose flottante" },
  { prestation: "parquet_contrecolle", gamme: "milieu", prix_m2: 90,  description: "Contrecollé chêne 14mm, pose collée" },
  { prestation: "parquet_contrecolle", gamme: "haut",   prix_m2: 125, description: "Contrecollé chêne premium, finition huilée" },

  # Parquet massif
  { prestation: "parquet_massif", gamme: "entree", prix_m2: 100, description: "Massif chêne 14mm, pose clouée" },
  { prestation: "parquet_massif", gamme: "milieu", prix_m2: 145, description: "Massif chêne 20mm premier choix" },
  { prestation: "parquet_massif", gamme: "haut",   prix_m2: 190, description: "Massif essences nobles, pose traditionnelle clouée" }
]

TARIFS.each do |attrs|
  Tarif.find_or_initialize_by(prestation: attrs[:prestation], gamme: attrs[:gamme]).tap do |t|
    t.prix_m2 = attrs[:prix_m2]
    t.description = attrs[:description]
    t.unite = "m2"
    t.actif = true
    t.save!
  end
end

puts "✓ #{Tarif.count} tarifs chargés (#{Tarif.actifs.count} actifs)"

# Contenu éditable (textes, emplacements photos, galerie réalisations)
load Rails.root.join("db/seeds/site_texts.rb")
load Rails.root.join("db/seeds/media_slots.rb")
load Rails.root.join("db/seeds/realisations.rb")
