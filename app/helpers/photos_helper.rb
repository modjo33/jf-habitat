module PhotosHelper
  UNSPLASH_BASE = "https://images.unsplash.com".freeze

  # Banque de photos stock (Unsplash) utilisée en FALLBACK uniquement.
  # Dès qu'une image est uploadée dans /admin/media_slots pour la clé donnée,
  # c'est elle qui s'affiche. Tant qu'aucun upload n'a été fait, on retombe
  # ici. Chaque clé doit avoir son MediaSlot déclaré dans seeds/media_slots.rb.
  STOCK = {
    # --- Home ---
    "hero_main"        => "photo-1583847268964-b28dc8f51f92",
    "hero_detail"      => "photo-1580398814575-816cf5faebad",
    "intro_ambiance"   => "photo-1610307540583-7472788642d6",

    # --- Services cards ---
    "service_peinture" => "photo-1525909002-1b05e0c869d8",
    "service_placo"    => "photo-1768321902331-7d21aa3faf5a",
    "service_parquet"  => "photo-1580398814575-816cf5faebad",

    # --- Bloc ambiances ---
    "ambiance_1"       => "photo-1614628079765-6c164f4bd970",
    "ambiance_2"       => "photo-1747336754870-ca7b10cc75f5",
    "ambiance_3"       => "photo-1566663409293-585e129d2e71",
    "ambiance_4"       => "photo-1571164860029-856acbc24b4a",

    # --- Pages internes ---
    "services_hero"    => "photo-1610307540583-7472788642d6",
    "contact_ambiance" => "photo-1747336754870-ca7b10cc75f5",
    "estimation_hero"  => "photo-1583847268964-b28dc8f51f92"
  }.freeze

  # Fallback Unsplash hardcodé pour la galerie /realisations tant que Johan
  # n'a pas créé ses propres Realisation depuis l'admin. Dès que ≥1 Realisation
  # active existe en DB, c'est elle qui pilote la galerie (sans fallback).
  GALLERY_FALLBACK_PHOTOS = {
    "realisation_peinture_1" => "photo-1525909002-1b05e0c869d8",
    "realisation_peinture_2" => "photo-1647996179012-66b87eba3d17",
    "realisation_peinture_3" => "photo-1674376360439-887ea33bce0d",
    "realisation_peinture_4" => "photo-1688372198189-de6a51777a81",
    "realisation_peinture_5" => "photo-1694159783550-899168cf0ec3",
    "realisation_placo_1"    => "photo-1768321902331-7d21aa3faf5a",
    "realisation_placo_2"    => "photo-1768321903410-54961e343b71",
    "realisation_placo_3"    => "photo-1768321917995-2d992c50854b",
    "realisation_placo_4"    => "photo-1751486403890-793880b12adb",
    "realisation_placo_5"    => "photo-1768321916128-c242ca443253",
    "realisation_parquet_1"  => "photo-1580398814575-816cf5faebad",
    "realisation_parquet_2"  => "photo-1562582664-8a8803c031ca",
    "realisation_parquet_3"  => "photo-1648624219254-1adcd4e49bc6",
    "realisation_parquet_4"  => "photo-1487266659293-c4762f375955",
    "realisation_parquet_5"  => "photo-1580398425599-3cd49b289433",
    "realisation_parquet_6"  => "photo-1508920052992-6f5a921eba78"
  }.freeze

  GALLERY_FALLBACK_LEGENDES = [
    { key: "realisation_parquet_1",  metier: "parquet",  legende: "Parquet chêne contrecollé · salon 32 m²" },
    { key: "realisation_peinture_2", metier: "peinture", legende: "Peinture mate haut de gamme · séjour" },
    { key: "realisation_placo_1",    metier: "placo",    legende: "Cloison placo + doublage isolant" },
    { key: "realisation_parquet_3",  metier: "parquet",  legende: "Parquet stratifié + plinthes laquées" },
    { key: "realisation_peinture_5", metier: "peinture", legende: "Peinture satinée · salle à manger" },
    { key: "realisation_placo_2",    metier: "placo",    legende: "Ossature métallique BA13 · chantier neuf" },
    { key: "realisation_parquet_5",  metier: "parquet",  legende: "Parquet chêne massif · pose collée" },
    { key: "realisation_peinture_3", metier: "peinture", legende: "Mur d'accent peinture jaune ocre" },
    { key: "realisation_placo_4",    metier: "placo",    legende: "Plâtrerie traditionnelle finition lisse" },
    { key: "realisation_parquet_2",  metier: "parquet",  legende: "Parquet lumineux + plinthes blanches" },
    { key: "realisation_peinture_4", metier: "peinture", legende: "Peinture chambre · finition veloutée" },
    { key: "realisation_placo_3",    metier: "placo",    legende: "Plafond suspendu + intégrations spots" },
    { key: "realisation_parquet_4",  metier: "parquet",  legende: "Parquet ample · grand salon ouvert" },
    { key: "realisation_peinture_1", metier: "peinture", legende: "Préparation peintures multi-finitions" },
    { key: "realisation_placo_5",    metier: "placo",    legende: "Aménagement combles + isolation" },
    { key: "realisation_parquet_6",  metier: "parquet",  legende: "Parquet stratifié AC4 · couloir" }
  ].freeze

  # URL d'une photo d'emplacement (hero, services, ambiances...).
  # Vérifie d'abord si l'admin a uploadé une image pour cette clé, sinon
  # retombe sur l'URL CDN Unsplash hardcodée.
  def stock_photo_url(name, w: 1600, h: nil, q: 80)
    key = name.to_s
    slot = MediaSlot.find_by(key: key)
    return slot.image_url(w: w, h: h) if slot&.image&.attached?

    photo_id = STOCK[key] || GALLERY_FALLBACK_PHOTOS[key]
    raise ArgumentError, "Photo stock inconnue : #{key}" unless photo_id

    unsplash_url(photo_id, w: w, h: h, q: q)
  end

  # Données de la galerie réalisations.
  # - Si ≥1 Realisation active en DB : on les renvoie (avec leur photo Active Storage).
  # - Sinon : on renvoie le fallback Unsplash hardcodé.
  # Chaque item retourné contient au minimum : :url, :metier, :legende.
  def gallery_items
    db_items = Realisation.active.ordered
    if db_items.any?
      db_items.map do |r|
        {
          url:     r.photo_url(w: 900, h: 1100) || unsplash_url(GALLERY_FALLBACK_PHOTOS["realisation_#{r.metier}_1"], w: 900, h: 1100),
          metier:  r.metier,
          legende: r.legende
        }
      end
    else
      GALLERY_FALLBACK_LEGENDES.map do |item|
        {
          url:     unsplash_url(GALLERY_FALLBACK_PHOTOS[item[:key]], w: 900, h: 1100),
          metier:  item[:metier],
          legende: item[:legende]
        }
      end
    end
  end

  private

  def unsplash_url(photo_id, w:, h: nil, q: 80)
    parts = ["w=#{w}", "q=#{q}", "fit=crop", "auto=format"]
    parts << "h=#{h}" if h
    "#{UNSPLASH_BASE}/#{photo_id}?#{parts.join('&')}"
  end
end
