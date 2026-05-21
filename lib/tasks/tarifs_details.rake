namespace :tarifs do
  desc "Renseigne le champ details (En savoir plus) par prestation×gamme — sans écraser ce qui est déjà saisi"
  task set_details: :environment do
    details = {
      "peinture_murs_reno" => {
        "entree" => "Dépoussiérage et rebouchage des petits trous et fissures. 2 couches de peinture acrylique mate. Protection des sols, plinthes et interrupteurs. Idéal pour rafraîchir une pièce en bon état.",
        "milieu" => "Préparation soignée : rebouchage, ponçage, sous-couche d'accrochage. 2 couches de peinture acrylique mate ou satinée de marque, lessivable. Reprises et raccords nets. Le meilleur rapport durabilité / prix.",
        "haut"   => "Préparation complète : rebouchage profond, enduit de lissage, ponçage fin, sous-couche garnissante. Peintures premium haute opacité, sans COV. Finitions impeccables, idéal pièces de réception."
      },
      "peinture_murs_neuf" => {
        "entree" => "Sur placo neuf : impression d'accrochage + 2 couches de peinture acrylique mate. Garnissage des bandes si nécessaire.",
        "milieu" => "Impression spécifique placo, ratissage des bandes, 2 couches de peinture satinée lessivable de marque. Surface parfaitement uniforme.",
        "haut"   => "Préparation « prête à décorer » (ratissage complet, ponçage fin), peintures premium, finition velours haut de gamme."
      },
      "peinture_plafond" => {
        "entree" => "Rebouchage léger. 2 couches de peinture plafond blanche anti-gouttes.",
        "milieu" => "Rebouchage et ponçage, sous-couche, 2 couches de peinture mate spéciale plafond. Traitement des auréoles si besoin.",
        "haut"   => "Remise à neuf complète (enduit, ponçage fin), peinture haut de gamme, blanc profond tendu sans reprise visible."
      },
      "peinture_plafond_neuf" => {
        "entree" => "Sur placo neuf : impression + 2 couches de peinture plafond blanche.",
        "milieu" => "Traitement des bandes, sous-couche, 2 couches de peinture mate spéciale plafond.",
        "haut"   => "Ratissage complet, ponçage fin, peinture premium, finition tendue sans défaut."
      },
      "placo_cloison" => {
        "entree" => "Ossature métallique + plaques BA13 standard. Bandes et enduit, surface prête à peindre.",
        "milieu" => "Ossature renforcée, plaques BA13 hydrofuge ou phonique selon la pièce, isolation laine intégrée, finition lissée.",
        "haut"   => "Cloison haute performance (phonique + hydrofuge), isolation renforcée, finition prête à décorer, intégrations sur mesure (niches, etc.)."
      },
      "placo_plafond" => {
        "entree" => "Plafond suspendu BA13 standard sur ossature. Bandes et enduit.",
        "milieu" => "Plafond BA13 avec isolation phonique, intégration des spots, finition lissée.",
        "haut"   => "Plafond acoustique premium, isolation renforcée, intégrations (spots, trappes) et finition haut de gamme."
      },
      "parquet_stratifie" => {
        "entree" => "Stratifié AC3, pose flottante sur sous-couche standard, plinthes assorties.",
        "milieu" => "Stratifié AC4 (passage élevé), sous-couche acoustique, pose flottante soignée, barres de seuil.",
        "haut"   => "Stratifié AC5 hydrofuge dernière génération, sous-couche premium phonique, pose et finitions haut de gamme."
      },
      "parquet_contrecolle" => {
        "entree" => "Contrecollé chêne 10 mm, pose flottante clipsable, plinthes.",
        "milieu" => "Contrecollé chêne 14 mm, pose collée sur ragréage, finition huilée ou vernie.",
        "haut"   => "Contrecollé chêne premium grande lame, pose collée, finition huilée naturelle, sur mesure."
      },
      "parquet_massif" => {
        "entree" => "Massif chêne 14 mm, pose clouée sur lambourdes.",
        "milieu" => "Massif chêne 20 mm premier choix, pose clouée ou collée, ponçage et vitrification.",
        "haut"   => "Massif essences nobles, pose traditionnelle, ponçage soigné, finition huile-cire haut de gamme."
      }
    }

    count = 0
    details.each do |prestation, par_gamme|
      par_gamme.each do |gamme, texte|
        t = Tarif.find_by(prestation: prestation, gamme: gamme)
        next unless t
        next if t.details.present? # ne pas écraser un texte déjà saisi par Johan
        t.update!(details: texte)
        count += 1
      end
    end
    puts "✓ #{count} détails renseignés"
    puts "TARIFS_SET_DETAILS_DONE"
  end
end
