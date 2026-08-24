# Mesure d'audience du tunnel d'estimation, côté SERVEUR.
#
# Pourquoi ne pas se contenter de GA4 : le tag Google est conditionné au
# consentement cookies. Un visiteur qui ignore le bandeau — le cas de la
# majorité du trafic mobile — n'y laisse aucune trace. On pouvait donc dépenser
# 30 €/jour de publicité sans jamais savoir si les gens arrivaient sur
# l'estimateur, ni où ils décrochaient.
#
# RGPD : aucune donnée personnelle. `visite` est un jeton aléatoire porté par la
# session Rails (cookie strictement nécessaire, déjà posé), jamais rapproché
# d'une identité, jamais partagé, jamais utilisé à d'autres fins que ce compteur
# agrégé. Ni IP, ni user-agent, ni identifiant publicitaire n'est conservé.
# Purge à 6 mois via `rake tunnel:purger`.
class EtapeTunnel < ApplicationRecord
  # Ordre du parcours = ordre de l'entonnoir affiché.
  ETAPES = {
    "arrivee"       => "Arrivée sur l'estimateur",
    "type_chantier" => "1 · Type de chantier",
    "pieces"        => "2 · Quelles pièces",
    "travaux_gamme" => "3 · Travaux & gamme",
    "dimensions"    => "4 · Dimensions",
    "precisions"    => "5 · Précisions",
    "contact"       => "6 · Coordonnées",
    "soumis"        => "Devis demandé"
  }.freeze

  # Hors entonnoir : un appel n'est pas une marche du parcours, c'est une sortie
  # par le côté. L'afficher dans le tableau lui donnerait un « taux de passage »
  # qui ne veut rien dire — il est compté à part.
  # `envoi_tente` / `envoi_bloque` séparent les deux façons de finir à zéro :
  # le visiteur n'a jamais tapé le bouton final (sujet d'offre, de confiance),
  # ou il l'a tapé et la validation l'a refusé (sujet de code). Sans elles, un
  # blocage silencieux a exactement la même signature qu'un renoncement — c'est
  # ce qui a fait accuser l'écran 1 pendant des semaines alors que le trou était
  # sur le dernier écran.
  HORS_ENTONNOIR = {
    "appel"        => "Appel déclenché",
    "envoi_tente"  => "Bouton final tapé",
    "envoi_bloque" => "Envoi refusé par la validation"
  }.freeze
  EVENEMENTS = ETAPES.merge(HORS_ENTONNOIR).freeze

  # Première étape émise par le JavaScript du wizard : elle part dès que
  # l'écran 1 s'affiche, en 0,7 s médiane après l'arrivée (mesuré en prod).
  # Une arrivée qui ne l'atteint jamais n'a donc PAS exécuté la page — robot à
  # user-agent normal, préchargement, ou clic qui n'a jamais rien affiché.
  # C'est elle, et non l'arrivée, qui compte les visiteurs réels : la comparer
  # à `arrivee` reviendrait à reprocher à l'écran 1 des départs qui n'ont
  # jamais eu lieu.
  ETAPE_NAVIGATEUR = "type_chantier"

  SOURCES   = %w[ads autre direct].freeze
  APPAREILS = %w[mobile tablette ordinateur autre].freeze

  RETENTION = 6.months

  validates :visite, :etape, presence: true
  validates :etape, inclusion: { in: EVENEMENTS.keys }

  scope :sur, ->(debut, fin) { where(created_at: debut.beginning_of_day..fin.end_of_day) }

  # Écriture idempotente : l'unicité (visite, étape) est garantie par l'index,
  # une étape revisitée ne crée pas de doublon et ne lève pas d'erreur.
  # `detail` n'est gardé que pour `envoi_bloque` (le motif du refus) : c'est un
  # message générique du wizard, jamais une valeur saisie — et l'idempotence
  # fait qu'une visite refusée plusieurs fois ne garde que son PREMIER motif.
  def self.enregistrer(visite:, etape:, source: "direct", appareil: "autre", detail: nil)
    return unless visite.present? && EVENEMENTS.key?(etape)

    insert_all(
      [ {
        visite: visite.to_s[0, 32],
        etape: etape,
        source: SOURCES.include?(source) ? source : "direct",
        appareil: APPAREILS.include?(appareil) ? appareil : "autre",
        detail: etape == "envoi_bloque" ? detail.presence&.slice(0, 120) : nil,
        created_at: Time.current
      } ],
      unique_by: %i[visite etape]
    )
  rescue ActiveRecord::ActiveRecordError => e
    # La mesure ne doit jamais casser une page publique.
    Rails.logger.warn "[EtapeTunnel] écriture ignorée : #{e.class} · #{e.message}"
  end

  # { "arrivee" => 42, "pieces" => 30, ... } — une visite comptée une fois.
  def self.compteurs(debut:, fin:, source: nil, appareil: nil)
    scope = sur(debut, fin)
    scope = scope.where(source: source)     if source.present?
    scope = scope.where(appareil: appareil) if appareil.present?
    scope.group(:etape).count
  end

  # Entonnoir prêt à afficher : une ligne par étape, avec le taux de passage
  # depuis l'étape précédente.
  #
  # Les pourcentages sont rapportés aux VISITEURS RÉELS (`ETAPE_NAVIGATEUR`),
  # pas aux arrivées : les arrivées incluent tout ce qui charge l'URL sans
  # jamais l'afficher, et les diluer dans le taux ferait passer un tunnel sain
  # pour une passoire. La ligne d'arrivée reste affichée — l'écart entre elle
  # et la suivante est un signal en soi — mais elle est marquée `hors_tunnel`
  # pour que la vue ne la traite pas comme une fuite d'écran.
  def self.entonnoir(debut:, fin:, source: nil, appareil: nil)
    compte = compteurs(debut: debut, fin: fin, source: source, appareil: appareil)
    base = compte[ETAPE_NAVIGATEUR].to_i
    precedent = nil

    ETAPES.map do |cle, libelle|
      n = compte[cle].to_i
      hors_tunnel = cle == "arrivee"
      ligne = {
        etape: cle,
        libelle: libelle,
        visites: n,
        hors_tunnel: hors_tunnel,
        # La perte de cette ligne-ci, ce sont les arrivées sans navigateur :
        # elle se lit comme un taux d'exécution, pas comme un abandon.
        sans_navigateur: cle == ETAPE_NAVIGATEUR,
        part_depart: (!hors_tunnel && base.positive?) ? (n * 100.0 / base).round(1) : nil,
        passage: precedent.to_i.positive? ? (n * 100.0 / precedent).round(1) : nil,
        perdus: precedent ? [ precedent - n, 0 ].max : nil
      }
      precedent = n
      ligne
    end
  end

  # Visiteurs dont le navigateur a réellement exécuté l'estimateur.
  def self.navigateurs(debut:, fin:, source: nil, appareil: nil)
    compteurs(debut: debut, fin: fin, source: source, appareil: appareil)[ETAPE_NAVIGATEUR].to_i
  end

  # Répartition mobile / ordinateur sur les visites arrivées dans le tunnel.
  def self.par_appareil(debut:, fin:)
    sur(debut, fin).where(etape: "arrivee").group(:appareil).count
  end

  def self.par_source(debut:, fin:)
    sur(debut, fin).where(etape: "arrivee").group(:source).count
  end

  # Les appels sont la conversion invisible : le tag Google `click_to_call` est
  # conditionné au consentement cookies, donc il n'en voit presque aucun.
  def self.appels(debut:, fin:, source: nil, appareil: nil)
    scope = sur(debut, fin).where(etape: "appel")
    scope = scope.where(source: source)     if source.present?
    scope = scope.where(appareil: appareil) if appareil.present?
    scope.count
  end

  # Dernier écran : combien ont tapé le bouton, combien ont été refusés, et
  # combien de refus sont restés sans suite. Un `bloques` élevé est un défaut de
  # code (un champ que le visiteur ne peut pas satisfaire), pas un renoncement.
  def self.dernier_ecran(debut:, fin:, source: nil, appareil: nil)
    compte = compteurs(debut: debut, fin: fin, source: source, appareil: appareil)
    tentes  = compte["envoi_tente"].to_i
    bloques = compte["envoi_bloque"].to_i
    {
      arrives: compte["contact"].to_i,
      tentes: tentes,
      bloques: bloques,
      soumis: compte["soumis"].to_i,
      # Part des visiteurs qui ont tapé le bouton sans jamais aboutir.
      bloques_pct: tentes.positive? ? (bloques * 100.0 / tentes).round(1) : nil
    }
  end

  # { "Merci d'indiquer votre téléphone." => 3, ... } — dit QUEL champ arrête
  # les visiteurs refusés. Les lignes d'avant la colonne `detail` sortent en
  # « motif non enregistré » plutôt que de disparaître du total.
  def self.motifs_blocage(debut:, fin:, source: nil, appareil: nil)
    scope = sur(debut, fin).where(etape: "envoi_bloque")
    scope = scope.where(source: source)     if source.present?
    scope = scope.where(appareil: appareil) if appareil.present?
    scope.group(:detail).count
         .transform_keys { |motif| motif.presence || "motif non enregistré" }
         .sort_by { |_, n| -n }
  end

  def self.purger(avant: RETENTION.ago)
    where(created_at: ...avant).delete_all
  end
end
