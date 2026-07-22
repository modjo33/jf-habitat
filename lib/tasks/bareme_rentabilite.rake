# Pré-remplit le barème interne (rendement + coût matière) utilisé par
# l'analyse de rentabilité des devis.
#
# IDEMPOTENT et NON DESTRUCTIF : ne renseigne que les cases encore vides, pour
# ne jamais écraser les valeurs que Johan a calées sur son rythme réel.
#
# ⚠️ Ces chiffres sont des ORDRES DE GRANDEUR du métier, pas des mesures. Ils
# servent d'amorce ; c'est le back-test des chantiers réels qui les corrige.
namespace :bareme do
  # rendement = m²/heure (main-d'œuvre seule) · matiere = € TTC/m²
  TARIFS_BAREME = {
    # prestation                gamme      rendement  matière
    ["peinture_murs_reno",     "entree"] => [8.0,  1.60],
    ["peinture_murs_reno",     "milieu"] => [7.0,  2.40],
    ["peinture_murs_reno",     "haut"]   => [6.0,  3.80],
    ["peinture_murs_neuf",     "entree"] => [10.0, 1.40],
    ["peinture_murs_neuf",     "milieu"] => [9.0,  2.10],
    ["peinture_murs_neuf",     "haut"]   => [7.5,  3.40],
    ["peinture_plafond",       "entree"] => [6.0,  1.80],
    ["peinture_plafond",       "milieu"] => [5.5,  2.60],
    ["peinture_plafond",       "haut"]   => [4.5,  4.00],
    ["peinture_plafond_neuf",  "entree"] => [7.5,  1.50],
    ["peinture_plafond_neuf",  "milieu"] => [6.5,  2.30],
    ["peinture_plafond_neuf",  "haut"]   => [5.5,  3.60],
    ["placo_cloison",          "entree"] => [3.0,  14.00],
    ["placo_cloison",          "milieu"] => [2.6,  18.00],
    ["placo_cloison",          "haut"]   => [2.2,  24.00],
    ["placo_plafond",          "entree"] => [2.2,  15.00],
    ["placo_plafond",          "milieu"] => [2.0,  19.00],
    ["placo_plafond",          "haut"]   => [1.7,  25.00],
    ["placo_bandes_enduit",    "entree"] => [5.0,  1.20],
    ["placo_bandes_enduit",    "milieu"] => [4.5,  1.70],
    ["placo_bandes_enduit",    "haut"]   => [3.8,  2.40],
    ["parquet_stratifie",      "entree"] => [6.0,  12.00],
    ["parquet_stratifie",      "milieu"] => [5.5,  20.00],
    ["parquet_stratifie",      "haut"]   => [5.0,  32.00],
    ["parquet_contrecolle",    "entree"] => [4.5,  28.00],
    ["parquet_contrecolle",    "milieu"] => [4.0,  42.00],
    ["parquet_contrecolle",    "haut"]   => [3.5,  60.00],
    ["parquet_massif",         "entree"] => [3.5,  45.00],
    ["parquet_massif",         "milieu"] => [3.0,  65.00],
    ["parquet_massif",         "haut"]   => [2.5,  95.00],
    ["poncage",                "milieu"] => [5.0,  2.50],
    ["poncage_peinture",       "milieu"] => [10.0, 0.40],
    ["depose_evacuation",      "milieu"] => [12.0, 0.00]
  }.freeze

  # Bibliothèque des lignes libres, repérée par mot-clé du nom.
  PRESTATIONS_BAREME = [
    [/sous-couche|impression/i, 9.0,  1.90],
    [/2 couches|deux couches|peinture/i, 8.0, 2.20],
    [/pon[cç]age|[ée]grenage/i, 10.0, 0.40],
    [/rebouchage|enduit/i,      6.0,  1.10],
    [/ratissage/i,              5.0,  1.60],
    [/protection|b[aâ]chage/i,  25.0, 0.60],
    [/lessivage|nettoyage/i,    20.0, 0.30],
    [/parquet/i,                5.5,  20.00],
    [/placo|cloison/i,          2.6,  18.00]
  ].freeze

  desc "Pré-remplit le barème rendement/coût matière (n'écrase jamais l'existant)"
  task seed: :environment do
    poses = 0
    ignores = 0

    TARIFS_BAREME.each do |(prestation, gamme), (rendement, matiere)|
      tarif = Tarif.find_by(prestation: prestation, gamme: gamme)
      next unless tarif
      attrs = {}
      attrs[:rendement_m2_h]     = rendement if tarif.rendement_m2_h.blank?
      attrs[:cout_matiere_unite] = matiere   if tarif.cout_matiere_unite.blank?
      if attrs.any?
        tarif.update_columns(attrs)
        poses += 1
        puts "  ✓ Tarif #{prestation}/#{gamme} → #{attrs.inspect}"
      else
        ignores += 1
      end
    end

    Prestation.find_each do |p|
      next if p.rendement_m2_h.present? && p.cout_matiere_unite.present?
      match = PRESTATIONS_BAREME.find { |regex, _, _| p.nom =~ regex }
      next unless match
      _, rendement, matiere = match
      attrs = {}
      attrs[:rendement_m2_h]     = rendement if p.rendement_m2_h.blank?
      attrs[:cout_matiere_unite] = matiere   if p.cout_matiere_unite.blank?
      next if attrs.empty?
      p.update_columns(attrs)
      poses += 1
      puts "  ✓ Prestation « #{p.nom} » → #{attrs.inspect}"
    end

    puts "\n#{poses} ligne(s) complétée(s), #{ignores} déjà renseignée(s) et laissée(s) telle(s) quelle(s)."
    puts "⚠️  Valeurs indicatives : à recaler sur ton rythme réel dans /admin/tarifs et /admin/prestations."
  end
end
