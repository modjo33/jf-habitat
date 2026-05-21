namespace :seo do
  desc "Met à jour les textes SiteText avec un ciblage géographique local (Gironde / Bordeaux)"
  task localize: :environment do
    updates = {
      "home.hero.body" =>
        "Trois métiers complémentaires, un seul interlocuteur en Gironde. Des chantiers menés avec exigence, des finitions qui durent, un devis honnête — et une estimation en ligne en deux minutes pour vous projeter, sans engagement.",
      "home.services.subtitle" =>
        "Une prise en charge globale en Gironde et sur Bordeaux Métropole, du gros œuvre aux finitions, pour des chantiers parfaitement coordonnés.",
      "footer.tagline" =>
        "Artisan peintre, plaquiste et parqueteur à Ayguemorte-les-Graves (33). Travaux de peinture, placo et parquet en Gironde et sur Bordeaux Métropole, en rénovation comme en neuf, avec une exigence haut de gamme.",
      "contact.hero.body" =>
        "Une question, un projet, un rendez-vous en Gironde ? Le plus rapide reste l'estimation en ligne — sinon écrivez-nous, je réponds sous 24h."
    }

    updates.each do |key, value|
      rec = SiteText.find_by(key: key)
      if rec
        rec.update!(value: value)
        puts "✓ MAJ #{key}"
      else
        puts "✗ clé absente: #{key}"
      end
    end
    puts "SEO_LOCALIZE_DONE"
  end
end
