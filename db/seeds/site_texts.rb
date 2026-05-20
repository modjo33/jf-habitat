# Clés de textes éditables depuis /admin/site_texts.
# Chaque clé suit une convention `page.section.element` pour rester lisible.
# Le `value` est le contenu par défaut (qui sert aussi de fallback si la BDD
# est vidée). Le `description` aide Johan à savoir où ce texte apparaît.

SITE_TEXTS = [
  # --- HOME / hero ---
  { key: "home.hero.eyebrow",     value: "Artisan · Peinture · Placo · Parquet",
    description: "Petit label au-dessus du gros titre de la home (hero)." },
  { key: "home.hero.title_line1", value: "L'intérieur qui vous ressemble,",
    description: "Première ligne du titre du hero de la home." },
  { key: "home.hero.title_line2", value: "par la main d'un artisan.",
    description: "Deuxième ligne du titre du hero — affichée en accent terracotta italique." },
  { key: "home.hero.body",
    value: "Trois métiers complémentaires, un seul interlocuteur. Des chantiers menés avec exigence, des finitions qui durent, un devis honnête — et une estimation en ligne en deux minutes pour vous projeter, sans engagement.",
    description: "Paragraphe sous le titre du hero de la home." },

  # --- HOME / manifesto ---
  { key: "home.manifesto.eyebrow", value: "Notre manifeste",
    description: "Eyebrow de la section manifesto (avec photo verticale)." },
  { key: "home.manifesto.title_part1", value: "La",
    description: "Manifesto — début du titre avant le mot accent." },
  { key: "home.manifesto.title_accent", value: "finition",
    description: "Mot mis en accent terracotta dans le titre manifesto." },
  { key: "home.manifesto.title_part2", value: "fait toute la différence — et la finition, ça se voit dans les détails.",
    description: "Manifesto — suite du titre après le mot accent." },
  { key: "home.manifesto.para1",
    value: "Une peinture qui dure, c'est d'abord un mur bien préparé. Un parquet qui résiste, c'est une pose sans compromis. Une cloison placo invisible, c'est trois passes de finition au lieu d'une.",
    description: "Premier paragraphe du manifesto." },
  { key: "home.manifesto.para2",
    value: "Chez JF Habitat, on ne fait pas de demi-mesure : on prend le temps qu'il faut, on ne sous-traite pas, on travaille avec des matériaux que l'on assume — et on tient le délai annoncé.",
    description: "Deuxième paragraphe du manifesto." },

  # --- HOME / services ---
  { key: "home.services.eyebrow", value: "Nos expertises",
    description: "Eyebrow de la section 3 métiers de la home." },
  { key: "home.services.title", value: "Trois métiers, un seul artisan.",
    description: "Titre de la section 3 métiers." },
  { key: "home.services.subtitle",
    value: "Une prise en charge globale pour des chantiers parfaitement coordonnés, du gros œuvre aux finitions.",
    description: "Sous-titre de la section 3 métiers." },

  # --- HOME / ambiances ---
  { key: "home.ambiances.eyebrow", value: "Ambiances",
    description: "Eyebrow de la section grille photos ambiances." },
  { key: "home.ambiances.title", value: "Des intérieurs qui se vivent.",
    description: "Titre de la section ambiances." },
  { key: "home.ambiances.body",
    value: "Chaque chantier est unique. Quelques exemples de finitions livrées, pour vous donner le ton.",
    description: "Paragraphe à droite du titre de la section ambiances." },

  # --- HOME / estimation CTA bandeau sombre ---
  { key: "home.estimation_cta.title",
    value: "Votre devis détaillé, en deux minutes.",
    description: "Titre du bandeau sombre CTA estimation (en bas de home)." },
  { key: "home.estimation_cta.body",
    value: "Saisissez vos pièces, vos surfaces, la gamme souhaitée — puis vos coordonnées. Notre estimateur applique les coefficients régionaux, les options techniques et les remises grand chantier, et vous envoie votre devis détaillé (HT, TVA, TTC + PDF) dès la soumission.",
    description: "Paragraphe sous le titre du bandeau CTA estimation." },

  # --- SERVICES page ---
  { key: "services.hero.eyebrow", value: "Prestations",
    description: "Eyebrow du hero de la page services." },
  { key: "services.hero.title", value: "Trois spécialités, une exigence commune.",
    description: "Titre du hero services." },
  { key: "services.hero.body",
    value: "Tout ce qu'il faut pour rénover ou aménager un intérieur, géré par le même artisan — pas de sous-traitance, pas de coordination à faire, un seul interlocuteur du premier au dernier jour.",
    description: "Paragraphe du hero services." },

  # --- REALISATIONS page ---
  { key: "realisations.hero.eyebrow", value: "Galerie · Sélection 2026",
    description: "Eyebrow du hero galerie réalisations." },
  { key: "realisations.hero.title", value: "Quelques chantiers, beaucoup d'attention.",
    description: "Titre du hero galerie réalisations." },
  { key: "realisations.hero.body",
    value: "Chaque projet est unique. Voici un aperçu de nos réalisations en peinture, placo et parquet — des finitions pensées dans le détail, des matériaux assumés, des clients satisfaits.",
    description: "Paragraphe du hero galerie réalisations." },

  # --- CONTACT page ---
  { key: "contact.hero.eyebrow", value: "Parlons de votre projet",
    description: "Eyebrow du hero contact." },
  { key: "contact.hero.title", value: "Contactez JF Habitat.",
    description: "Titre du hero contact." },
  { key: "contact.hero.body",
    value: "Une question, un projet, un rendez-vous ? Le plus rapide reste l'estimation en ligne — sinon écrivez-nous, nous répondons sous 24h.",
    description: "Paragraphe du hero contact." },

  # --- ESTIMATION new page ---
  { key: "estimation_new.hero.eyebrow", value: "Estimation en ligne",
    description: "Eyebrow du hero formulaire d'estimation." },
  { key: "estimation_new.hero.title", value: "Construisons votre estimation.",
    description: "Titre du formulaire d'estimation." },
  { key: "estimation_new.hero.body",
    value: "Dimensions précises, options, déductions d'ouvertures. L'estimation s'ajuste en temps réel.",
    description: "Paragraphe du hero formulaire d'estimation." },

  # --- FOOTER ---
  { key: "footer.tagline",
    value: "Artisan peintre, plaquiste et parqueteur. Travaux de rénovation et de construction neuve, avec une exigence haut de gamme et le souci du détail.",
    description: "Phrase descriptive sous le logo dans le footer." }
].freeze

SITE_TEXTS.each do |attrs|
  rec = SiteText.find_or_initialize_by(key: attrs[:key])
  rec.value       = attrs[:value]       if rec.value.blank?
  rec.description = attrs[:description]
  rec.save!
end

puts "✓ #{SiteText.count} textes du site chargés"
