class PagesController < ApplicationController
  def home
  end

  def services
  end

  # La peinture d'abord (cœur de métier mis en avant), le placo en dernier.
  ORDRE_METIERS = %w[peinture parquet placo].freeze

  def prestations
    # Comparatif des gammes par prestation, regroupé par métier.
    tarifs = Tarif.actifs.to_a
    @prestations_par_metier = Tarif::PRESTATIONS_CHOISISSABLES.group_by { |_k, v| v[:categorie] }.transform_values do |list|
      list.map do |key, meta|
        gammes = Tarif::GAMMES.keys.index_with do |g|
          tarifs.find { |t| t.prestation == key && t.gamme == g }
        end
        { key: key, label: meta[:label], gammes: gammes }
      end
    end.sort_by { |metier, _| ORDRE_METIERS.index(metier) || ORDRE_METIERS.size }.to_h
  end

  def realisations
  end

  # Contenu des pages d'atterrissage Ads. Le texte vit ici (pas en SiteText) :
  # il est calibré mot-clé par mot-clé pour le niveau de qualité, le modifier
  # à la volée depuis l'admin le désaccorderait des annonces.
  LANDINGS = {
    "peinture" => {
      accroche: "Murs, plafonds, boiseries : préparation soignée, finitions nettes, prix annoncé avant de commencer.",
      titre_seo: "Peintre en bâtiment à Bordeaux & Gironde Sud — devis en 2 min · JF Habitat",
      desc_seo: "Entreprise de peinture à Bordeaux et en Gironde Sud : murs, plafonds, boiseries, neuf et rénovation. Artisan local, devis peinture détaillé en ligne en 2 minutes, gratuit et sans engagement.",
      eyebrow: "Artisan peintre · Bordeaux & Gironde Sud",
      h1: "Peintre en bâtiment à Bordeaux",
      h1_accent: "et en Gironde Sud",
      intro: "Vous cherchez un peintre pour rafraîchir une pièce, repeindre tout un appartement ou finir un chantier neuf ? JF Habitat est une entreprise de peinture artisanale installée à Ayguemorte-les-Graves : préparation des supports soignée, finitions nettes, tarifs annoncés avant le premier coup de pinceau.",
      photo: :service_peinture,
      photo_alt: "Peintre en bâtiment appliquant une peinture murale, chantier JF Habitat à Bordeaux",
      prestations: [
        ["Peinture murs & plafonds", "Rebouchage, enduit, sous-couche et 2 couches de finition — mat, velours ou satin.", "dès 18 €/m²"],
        ["Rénovation complète", "Appartement ou maison : protection, préparation des supports abîmés, mise en peinture pièce par pièce.", "sur devis"],
        ["Boiseries & radiateurs", "Portes, plinthes, volets, radiateurs : ponçage, impression et laque tendue.", "sur devis"],
        ["Enduit & lissage", "Reprise des fissures, ratissage complet des murs anciens avant peinture.", "dès 23 €/m²"]
      ],
      faq: [
        ["Combien coûte un peintre à Bordeaux ?", "Comptez entre 18 et 35 €/m² de surface peinte selon l'état du support et la finition choisie, préparation et fournitures comprises. L'estimateur en ligne vous donne un chiffrage détaillé, ligne par ligne, en 2 minutes."],
        ["Le devis est-il vraiment gratuit ?", "Oui. L'estimation en ligne est immédiate et sans engagement, et je me déplace gratuitement pour affiner le devis sur place si le chantier le demande."],
        ["Sous quel délai pouvez-vous intervenir ?", "En général sous 2 à 4 semaines selon la taille du chantier. Un rafraîchissement d'une pièce peut souvent se caler plus vite."],
        ["Travaillez-vous en neuf comme en rénovation ?", "Les deux. Rénovation de murs anciens (rebouchage, enduit, toile de verre) comme finitions de chantier neuf après placo."]
      ]
    },
    "placo" => {
      accroche: "Cloisons, doublages isolants, plafonds — et la peinture de finition par le même artisan.",
      titre_seo: "Plaquiste à Bordeaux & Gironde Sud — cloisons, doublage, plafonds · JF Habitat",
      desc_seo: "Plaquiste-plâtrier à Bordeaux et en Gironde Sud : cloisons BA13, doublage isolant, plafonds, bandes et enduit, finition peinture possible. Devis placo détaillé en ligne en 2 minutes, gratuit.",
      eyebrow: "Plaquiste · Plâtrier · Bordeaux & Gironde Sud",
      h1: "Plaquiste à Bordeaux",
      h1_accent: "et en Gironde Sud",
      intro: "Créer une chambre, séparer un espace, isoler un mur froid ou refaire un plafond : JF Habitat réalise vos travaux de plâtrerie et de placo — ossature, plaques BA13, bandes et enduit — avec un vrai plus : le même artisan peut enchaîner sur la peinture de finition.",
      photo: :service_placo,
      photo_alt: "Pose de cloison en plaques de plâtre BA13 par un plaquiste, chantier JF Habitat",
      prestations: [
        ["Cloison placo", "Ossature métallique, isolation phonique, plaques BA13, bandes et enduit prêts à peindre.", "dès 50 €/m²"],
        ["Doublage isolant", "Doublage thermique ou phonique des murs existants, en ossature ou collé.", "dès 60 €/m²"],
        ["Plafond placo", "Plafonds suspendus, reprise de plafonds abîmés, intégration de spots.", "sur devis"],
        ["Bandes & enduit", "Ratissage des joints, finition lisse prête à peindre — ou peinture comprise si vous voulez du clé en main.", "sur devis"]
      ],
      faq: [
        ["Combien coûte une cloison en placo ?", "Comptez à partir de 50 €/m² de cloison posée (ossature, isolation, plaques, bandes), selon la hauteur et l'isolation choisie. L'estimateur en ligne chiffre votre cloison sur sa longueur réelle."],
        ["Faites-vous aussi la peinture après le placo ?", "Oui, c'est l'intérêt d'un artisan multi-métier : cloison, bandes, impression et peinture de finition dans le même devis, sans coordonner deux entreprises."],
        ["Intervenez-vous pour une seule cloison ?", "Oui. Une cloison de séparation, un doublage d'un seul mur ou un petit plafond sont des chantiers bienvenus — le devis en ligne les chiffre en 2 minutes."],
        ["Le placo est-il posé aux normes ?", "Ossature aux entraxes normalisés, vis et bandes selon les règles de l'art, garantie décennale : le chantier est fait pour durer et être repeint sans surprise."]
      ]
    },
    "parquet" => {
      accroche: "Flottant, contrecollé ou massif : pose nette, plinthes ajustées, sols anciens rénovés.",
      titre_seo: "Pose de parquet à Bordeaux & Gironde Sud — flottant, collé, ponçage · JF Habitat",
      desc_seo: "Parqueteur à Bordeaux et en Gironde Sud : pose de parquet flottant, contrecollé ou massif, ponçage et vitrification, plinthes. Devis parquet détaillé en ligne en 2 minutes, gratuit.",
      eyebrow: "Pose de parquet · Bordeaux & Gironde Sud",
      h1: "Pose de parquet à Bordeaux",
      h1_accent: "et en Gironde Sud",
      intro: "Un parquet bien posé change une pièce — et se joue à la préparation : sol plan, sous-couche adaptée, sens de pose réfléchi, plinthes ajustées. JF Habitat pose vos parquets stratifiés, contrecollés et massifs, et redonne vie aux parquets anciens par ponçage et vitrification.",
      photo: :service_parquet,
      photo_alt: "Parquet en chêne posé dans un salon lumineux, chantier JF Habitat à Bordeaux",
      prestations: [
        ["Parquet flottant & stratifié", "Sous-couche, pose flottante, seuils et finitions — la solution rapide et robuste.", "dès 30 €/m²"],
        ["Parquet contrecollé & massif", "Pose collée en plein ou clouée sur lambourdes, pour un sol qui traverse les décennies.", "sur devis"],
        ["Ponçage & vitrification", "Rénovation des parquets anciens : ponçage à blanc, teinte éventuelle, vitrificateur trafic intense.", "sur devis"],
        ["Plinthes & finitions", "Dépose des anciennes plinthes, pose des nouvelles, barres de seuil et ajustements.", "sur devis"]
      ],
      faq: [
        ["Combien coûte la pose d'un parquet ?", "À partir de 30 €/m² pour une pose flottante, davantage pour une pose collée ou clouée. L'estimateur en ligne vous chiffre la pièce en 2 minutes, fournitures de pose comprises."],
        ["Rénovez-vous les parquets anciens ?", "Oui : ponçage complet, réparation des lames abîmées, puis vitrification ou huilage selon le rendu voulu."],
        ["Quel parquet pour quelle pièce ?", "Stratifié AC4/AC5 pour les passages intenses, contrecollé pour le rapport qualité-prix, massif pour le cachet. On en parle au devis, sans vous pousser vers le plus cher."],
        ["Posez-vous sur un carrelage existant ?", "Souvent oui, en pose flottante avec la bonne sous-couche, si le sol est plan. C'est vérifié lors de la visite, avant tout engagement."]
      ]
    }
  }.freeze

  def landing
    @m = LANDINGS.fetch(params[:metier]) { return redirect_to(root_path) }
  end

  def contact
  end

  def mentions_legales
  end

  def politique_confidentialite
  end

  def cgu
  end

  def sitemap
    @urls = [
      { loc: root_url,                       priority: 1.0, changefreq: "weekly" },
      { loc: services_url,                   priority: 0.8, changefreq: "monthly" },
      { loc: prestations_url,                priority: 0.8, changefreq: "monthly" },
      { loc: realisations_url,               priority: 0.8, changefreq: "weekly" },
      { loc: contact_url,                    priority: 0.6, changefreq: "yearly" },
      { loc: new_estimation_url,             priority: 0.9, changefreq: "monthly" },
      { loc: landing_peinture_url,           priority: 0.8, changefreq: "monthly" },
      { loc: landing_placo_url,              priority: 0.8, changefreq: "monthly" },
      { loc: landing_parquet_url,            priority: 0.8, changefreq: "monthly" },
      { loc: mentions_legales_url,           priority: 0.2, changefreq: "yearly" },
      { loc: politique_confidentialite_url,  priority: 0.2, changefreq: "yearly" },
      { loc: cgu_url,                        priority: 0.2, changefreq: "yearly" }
    ]
    respond_to { |format| format.xml }
  end
end
