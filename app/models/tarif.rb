class Tarif < ApplicationRecord
  PRESTATIONS = {
    "peinture_murs_reno"    => { label: "Peinture murs (rénovation)",    icon: "paint_brush", categorie: "peinture" },
    "peinture_murs_neuf"    => { label: "Peinture murs (neuf)",          icon: "paint_brush", categorie: "peinture" },
    "peinture_plafond"      => { label: "Peinture plafond (rénovation)", icon: "paint_brush", categorie: "peinture" },
    "peinture_plafond_neuf" => { label: "Peinture plafond (neuf)",       icon: "paint_brush", categorie: "peinture" },
    "placo_cloison"         => { label: "Placo cloison",                 icon: "squares_2x2", categorie: "placo" },
    "placo_plafond"         => { label: "Placo plafond",                 icon: "squares_2x2", categorie: "placo" },
    "placo_bandes_enduit"   => { label: "Bandes & enduit (finition placo)", icon: "squares_2x2", categorie: "placo" },
    "parquet_stratifie"     => { label: "Parquet stratifié",             icon: "rectangle_stack", categorie: "parquet" },
    "parquet_contrecolle"   => { label: "Parquet contrecollé",           icon: "rectangle_stack", categorie: "parquet" },
    "parquet_massif"        => { label: "Parquet massif",                icon: "rectangle_stack", categorie: "parquet" },
    # Suppléments (options) — catégorie "supplement", exclues du choix de prestation,
    # éditables dans /admin/tarifs. Prix/m² ajouté à la ligne quand l'option est cochée.
    "poncage"               => { label: "Ponçage",                       icon: "sparkles", categorie: "supplement" },
    "depose_evacuation"     => { label: "Dépose & évacuation ancien revêtement", icon: "trash", categorie: "supplement" }
  }.freeze

  # Prestations réellement proposées dans le formulaire (hors suppléments).
  PRESTATIONS_CHOISISSABLES = PRESTATIONS.reject { |_k, v| v[:categorie] == "supplement" }.freeze

  GAMMES = {
    "entree"  => { label: "Entrée de gamme", description: "Finitions standards, matériaux courants" },
    "milieu"  => { label: "Milieu de gamme", description: "Bon rapport qualité-prix, finitions soignées" },
    "haut"    => { label: "Haut de gamme",   description: "Matériaux premium, finitions impeccables" }
  }.freeze

  validates :prestation, presence: true, inclusion: { in: PRESTATIONS.keys }
  validates :gamme, presence: true, inclusion: { in: GAMMES.keys }
  validates :prix_m2, presence: true, numericality: { greater_than: 0 }
  validates :prestation, uniqueness: { scope: :gamme }

  scope :actifs, -> { where(actif: true) }

  def self.prix_for(prestation:, gamme:)
    actifs.find_by(prestation: prestation, gamme: gamme)&.prix_m2
  end

  def prestation_label
    PRESTATIONS.dig(prestation, :label) || prestation
  end

  def gamme_label
    GAMMES.dig(gamme, :label) || gamme
  end

  def categorie
    PRESTATIONS.dig(prestation, :categorie)
  end
end
