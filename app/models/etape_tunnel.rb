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
  HORS_ENTONNOIR = { "appel" => "Appel déclenché" }.freeze
  EVENEMENTS = ETAPES.merge(HORS_ENTONNOIR).freeze

  SOURCES   = %w[ads autre direct].freeze
  APPAREILS = %w[mobile tablette ordinateur autre].freeze

  RETENTION = 6.months

  validates :visite, :etape, presence: true
  validates :etape, inclusion: { in: EVENEMENTS.keys }

  scope :sur, ->(debut, fin) { where(created_at: debut.beginning_of_day..fin.end_of_day) }

  # Écriture idempotente : l'unicité (visite, étape) est garantie par l'index,
  # une étape revisitée ne crée pas de doublon et ne lève pas d'erreur.
  def self.enregistrer(visite:, etape:, source: "direct", appareil: "autre")
    return unless visite.present? && EVENEMENTS.key?(etape)

    insert_all(
      [ {
        visite: visite.to_s[0, 32],
        etape: etape,
        source: SOURCES.include?(source) ? source : "direct",
        appareil: APPAREILS.include?(appareil) ? appareil : "autre",
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
  # depuis l'étape précédente et depuis l'arrivée.
  def self.entonnoir(debut:, fin:, source: nil, appareil: nil)
    compte = compteurs(debut: debut, fin: fin, source: source, appareil: appareil)
    depart = compte["arrivee"].to_i
    precedent = nil

    ETAPES.map do |cle, libelle|
      n = compte[cle].to_i
      ligne = {
        etape: cle,
        libelle: libelle,
        visites: n,
        part_depart: depart.positive? ? (n * 100.0 / depart).round(1) : nil,
        passage: precedent.to_i.positive? ? (n * 100.0 / precedent).round(1) : nil,
        perdus: precedent ? [ precedent - n, 0 ].max : nil
      }
      precedent = n
      ligne
    end
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

  def self.purger(avant: RETENTION.ago)
    where(created_at: ...avant).delete_all
  end
end
