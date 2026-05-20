# Emplacements photos du site. Tant qu'aucune image n'est uploadée depuis
# /admin/media_slots, le helper PhotosHelper#stock_photo_url retombe sur la
# photo Unsplash par défaut associée à cette clé.

MEDIA_SLOTS = [
  { key: "hero_main",        description: "HOME — grosse photo du hero (à droite du gros titre). Format paysage." },
  { key: "hero_detail",      description: "Photo de détail bois utilisée en arrière-plan des bandeaux sombres (estimation CTA, hero réalisations)." },
  { key: "intro_ambiance",   description: "HOME — photo verticale à gauche du manifesto. Format portrait." },

  { key: "service_peinture", description: "Carte service Peinture (home + bloc services). Format 4:3." },
  { key: "service_placo",    description: "Carte service Placo-plâtre (home + bloc services). Format 4:3." },
  { key: "service_parquet",  description: "Carte service Parquet (home + bloc services). Format 4:3." },

  { key: "ambiance_1",       description: "HOME — grille ambiances, photo n°1 (grande verticale gauche)." },
  { key: "ambiance_2",       description: "HOME — grille ambiances, photo n°2 (carrée)." },
  { key: "ambiance_3",       description: "HOME — grille ambiances, photo n°3 (carrée)." },
  { key: "ambiance_4",       description: "HOME — grille ambiances, photo n°4 (large bas)." },

  { key: "services_hero",    description: "Page Services — photo de fond du hero sombre." },
  { key: "contact_ambiance", description: "Page Contact — photo de fond du hero sombre." },
  { key: "estimation_hero",  description: "Page Estimation — photo de fond du hero sombre." }
].freeze

MEDIA_SLOTS.each do |attrs|
  rec = MediaSlot.find_or_initialize_by(key: attrs[:key])
  rec.description = attrs[:description]
  rec.save!
end

puts "✓ #{MediaSlot.count} emplacements photos déclarés"
