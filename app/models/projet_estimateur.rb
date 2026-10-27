# Projet laissé sur l'estimateur en ligne au moment où le visiteur donne son
# numéro, AVANT d'envoyer le formulaire (cf. EstimationsController#telephone).
#
# Il est rangé dans la note du site (ClientNote#donnees) et non dans une
# Estimation : une demande non envoyée compterait sinon comme un lead, gonflerait
# le CA en cours et le badge « nouveau ». Johan la transforme en vraie
# estimation d'un clic depuis la fiche client (#construire_estimation).
class ProjetEstimateur
  MAX_PIECES = 30
  MAX_LIGNES = 100
  PRECISIONS = {
    "etat" => "État des surfaces", "peinture" => "Type de peinture", "teintes" => "Teintes",
    "sol" => "Revêtement de sol actuel", "profil" => "Profil", "source" => "Origine du contact"
  }.freeze
  OPTIONS = EstimationLine::SUPPLEMENTS.transform_keys(&:to_s).transform_values { |v| v[:label] }.freeze
  CHAMPS_LIGNE = %w[piece type_piece prestation gamme surface poncage poncage_peinture depose_evacuation].freeze

  # Paramètres bruts du navigateur → Hash propre, borné, prêt pour le jsonb.
  # Renvoie nil quand il n'y a rien d'exploitable.
  def self.normaliser(brut)
    return nil if brut.blank?
    h = brut.respond_to?(:to_unsafe_h) ? brut.to_unsafe_h : brut.to_h
    h = h.deep_stringify_keys

    pieces = Array(h["pieces"]).first(MAX_PIECES).filter_map do |p|
      next unless p.is_a?(Hash)
      { "label" => texte(p["label"]), "type" => texte(p["type"], 30),
        "travaux" => Array(p["travaux"]).first(20).map { |t| texte(t) }.reject(&:empty?),
        "mode" => texte(p["mode"], 20), "surface_sol" => nombre(p["surface_sol"]),
        "hauteur" => nombre(p["hauteur"]), "murs" => nombre(p["murs"]),
        "sol" => nombre(p["sol"]), "cloison" => nombre(p["cloison"]) }
    end

    lignes = Array(h["lignes"]).first(MAX_LIGNES).filter_map do |l|
      next unless l.is_a?(Hash)
      ligne = CHAMPS_LIGNE.index_with { |k| texte(l[k], 60) }
      ligne["surface"] = nombre(l["surface"])
      ligne if ligne["prestation"].present? && ligne["surface"].positive?
    end

    precisions = (h["precisions"].is_a?(Hash) ? h["precisions"] : {})
                   .slice(*PRECISIONS.keys).transform_values { |v| texte(v, 200) }.reject { |_, v| v.empty? }

    chiffrage = nil
    if h["chiffrage"].is_a?(Hash) && nombre(h["chiffrage"]["total_ttc"]).positive?
      chiffrage = {
        "total_ttc" => nombre(h["chiffrage"]["total_ttc"]),
        "lignes" => Array(h["chiffrage"]["lignes"]).first(MAX_LIGNES).filter_map do |l|
          next unless l.is_a?(Hash)
          { "libelle" => texte(l["libelle"]), "surface" => nombre(l["surface"]), "total" => nombre(l["total"]) }
        end
      }
    end

    donnees = {
      "chantier" => texte(h["chantier"], 20), "gamme" => texte(h["gamme"], 20),
      "etage" => texte(h["etage"], 3), "code_postal" => texte(h["code_postal"], 5),
      "options" => Array(h["options"]).map(&:to_s) & OPTIONS.keys,
      "pieces" => pieces, "precisions" => precisions, "lignes" => lignes, "chiffrage" => chiffrage
    }.compact
    pieces.empty? && lignes.empty? ? nil : donnees
  end

  def self.texte(v, max = 120) = v.to_s.squish.first(max)
  def self.nombre(v) = (Float(v.to_s.tr(",", ".")) rescue 0.0).clamp(0, 100_000).round(2)
  private_class_method :texte, :nombre

  attr_reader :donnees

  def initialize(donnees)
    @donnees = (donnees || {}).deep_stringify_keys
  end

  def present? = pieces.any? || lignes.any?
  def pieces = Array(donnees["pieces"])
  def lignes = Array(donnees["lignes"])
  def precisions = (donnees["precisions"] || {}).map { |k, v| [PRECISIONS[k] || k, v] }
  def options = Array(donnees["options"]).map { |o| OPTIONS[o] || o }
  def chiffrage = donnees["chiffrage"]
  def code_postal = donnees["code_postal"].presence
  def etage = donnees["etage"].presence
  def chantier_label = Estimation::TYPES_CHANTIER[donnees["chantier"]]
  def gamme_label = Tarif::GAMMES.dig(donnees["gamme"], :label)
  def estimation = donnees["estimation_id"] && Estimation.find_by(id: donnees["estimation_id"])

  # Estimation « créée dans l'admin » (coordonnées facultatives) avec les lignes
  # du projet : Johan la retravaille ensuite comme n'importe quel devis.
  def construire_estimation(client, note)
    e = Estimation.new(
      origine: "manuel", statut: "nouveau", client: client,
      nom: client.nom, telephone: client.telephone, email: client.email.presence,
      type_chantier: (donnees["chantier"] if Estimation::TYPES_CHANTIER.key?(donnees["chantier"])),
      etage: donnees["etage"].to_i.clamp(0, 29),
      code_postal: (code_postal if code_postal.to_s.match?(/\A\d{5}\z/)),
      ville: client.ville, adresse: client.adresse,
      message: message(note)
    )
    lignes.each do |l|
      next unless Tarif::PRESTATIONS.key?(l["prestation"])
      e.estimation_lines.build(
        piece: l["piece"].presence || "Pièce",
        type_piece: (EstimationLine::TYPES_PIECE.key?(l["type_piece"]) ? l["type_piece"] : "autre"),
        prestation: l["prestation"],
        gamme: (Tarif::GAMMES.key?(l["gamme"]) ? l["gamme"] : "milieu"),
        mode_saisie: "surface", surface: l["surface"],
        poncage: l["poncage"] == "1", poncage_peinture: l["poncage_peinture"] == "1",
        depose_evacuation: l["depose_evacuation"] == "1"
      )
    end
    e
  end

  # Le devis estimatif tel que le visiteur l'a vu à l'écran, reconstitué en
  # mémoire (jamais enregistré) pour le PDF de la fiche client. Les prix sont
  # recalculés avec le barème du jour : la fiche affiche à côté le prix vu.
  def estimation_pour_pdf(client, note)
    e = construire_estimation(client, note)
    e.reference = "TEL-#{note.id}"
    e.created_at = note.created_at
    e.email = client.email.to_s
    e.telephone = client.telephone.to_s
    e.estimation_lines.each(&:valid?)
    e.calculer_coefficients
    e.recalculer_totaux
    e
  end

  private

  def message(note)
    lignes_msg = [ "Projet laissé sur l'estimateur le #{I18n.l(note.created_at, format: '%d/%m/%Y à %Hh%M')} " \
                   "(numéro donné, formulaire non envoyé)." ]
    if precisions.any?
      lignes_msg << "" << "— Précisions du formulaire —"
      lignes_msg += precisions.map { |k, v| "• #{k} : #{v}" }
    end
    lignes_msg << "• Options : #{options.join(', ')}" if options.any?
    lignes_msg.join("\n")
  end
end
