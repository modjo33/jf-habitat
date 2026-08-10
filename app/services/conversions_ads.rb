# Import de conversions « hors connexion » dans Google Ads, à partir du gclid.
#
# POURQUOI : le tag de conversion du site est conditionné au consentement
# cookies, et 87 % du trafic est mobile — presque personne n'accepte. Google
# enregistrait donc ZÉRO conversion alors que les leads arrivaient bien. Sans
# conversion, aucune enchère intelligente n'est possible : Google pilote à
# l'aveugle.
#
# Le gclid, lui, est capté dans l'URL par `SourceTrackable` et stocké sur
# l'estimation. Le renvoyer à Google par fichier contourne totalement le
# bandeau cookies, et fonctionne rétroactivement.
class ConversionsAds
  # ⚠️ Ces libellés doivent correspondre AU CARACTÈRE PRÈS au nom des actions
  # de conversion créées dans Google Ads (type « Importer → Autres sources de
  # données ou CRM »). Un écart = fichier rejeté.
  ACTION_LEAD  = "Devis demandé (import)".freeze
  ACTION_VENTE = "Devis accepté (import)".freeze

  # Valeur d'un lead = montant estimé × probabilité de le signer. Envoyer le
  # montant brut ferait croire à Google qu'un lead vaut 10 000 €, et il
  # surenchérirait. Le ratio garde le signal relatif (un gros chantier vaut
  # plus qu'un petit) en ramenant le montant à une espérance réaliste.
  TAUX_TRANSFORMATION = 0.20

  # Plancher : un lead dont le montant est inconnu vaut quand même quelque
  # chose. Envoyer 0,00 € reviendrait à dire à Google que cette conversion ne
  # mérite aucune enchère — pire que ne rien envoyer du tout.
  VALEUR_LEAD_MINIMALE = 50.0

  # Google refuse les conversions dont le clic est trop ancien. On reste sous
  # la fenêtre par défaut des actions de conversion.
  FENETRE_JOURS = 90

  TYPES = {
    "lead"  => { action: ACTION_LEAD,  colonne: :ads_export_lead_at,
                 libelle: "Devis demandés", description: "Toute estimation soumise depuis un clic publicitaire." },
    "vente" => { action: ACTION_VENTE, colonne: :ads_export_vente_at,
                 libelle: "Devis acceptés", description: "Les devis effectivement signés, avec leur montant réel." }
  }.freeze

  class << self
    def type?(type) = TYPES.key?(type.to_s)

    # Estimations éligibles : un gclid, et un clic assez récent pour que Google
    # l'accepte encore.
    def eligibles(type)
      scope = Estimation.where.not(gclid: [nil, ""])
                        .where("created_at >= ?", FENETRE_JOURS.days.ago)
      scope = scope.where.not(devis_accepte_at: nil) if type.to_s == "vente"
      scope.order(:created_at)
    end

    def deja_exportees(type) = dedoublonner(eligibles(type).where.not(TYPES[type.to_s][:colonne] => nil))
    def a_exporter(type)     = dedoublonner(eligibles(type).where(TYPES[type.to_s][:colonne] => nil))

    # Un clic publicitaire ne vaut qu'une conversion. Deux soumissions depuis le
    # même clic (cas vécu : le même visiteur a rempli le formulaire deux fois à
    # deux minutes d'intervalle) sont un seul lead — les envoyer toutes les deux
    # doublerait le compteur de Google et fausserait ses enchères.
    # On garde la première, l'ordre étant chronologique.
    def dedoublonner(scope) = scope.to_a.uniq(&:gclid)

    # Date retenue comme moment de la conversion : la soumission pour un lead,
    # l'acceptation du devis pour une vente.
    def horodatage(estimation, type)
      type.to_s == "vente" ? (estimation.devis_accepte_at || estimation.updated_at) : estimation.created_at
    end

    # Une vente vaut son devis réel. Un lead vaut ce qu'il a demandé en ligne,
    # pondéré par ses chances d'être signé — jamais moins que le plancher.
    def valeur(estimation, type)
      return estimation.devis_total.to_d.round(2) if type.to_s == "vente"

      attendue = (estimation.total_ttc.to_d * TAUX_TRANSFORMATION).round(2)
      [attendue, VALEUR_LEAD_MINIMALE.to_d].max
    end

    # Fichier au format attendu par Google Ads.
    # ⚠️ PAS de BOM UTF-8 ici (contrairement à l'export du livre des recettes) :
    # l'analyseur de Google lirait le BOM comme faisant partie du premier
    # en-tête et rejetterait le fichier.
    def csv(type, estimations = nil)
      conf = TYPES.fetch(type.to_s)
      lignes = estimations || a_exporter(type)

      out = +"Parameters:TimeZone=Europe/Paris\n"
      out << "Google Click ID,Conversion Name,Conversion Time,Conversion Value,Conversion Currency\n"
      lignes.each do |e|
        out << [
          e.gclid,
          conf[:action],
          horodatage(e, type).in_time_zone("Europe/Paris").strftime("%Y-%m-%d %H:%M:%S"),
          format("%.2f", valeur(e, type)),
          "EUR"
        ].map { |c| echapper(c) }.join(",") << "\n"
      end
      out
    end

    def nom_fichier(type)
      "conversions-google-ads-#{type}-#{Date.current.strftime('%Y%m%d')}.csv"
    end

    # On marque PAR GCLID, pas par identifiant : sinon le doublon écarté à
    # l'export ressortirait au tour suivant, une fois son jumeau marqué.
    def marquer!(type, estimations)
      colonne = TYPES.fetch(type.to_s)[:colonne]
      gclids  = Array(estimations).map(&:gclid).compact_blank
      return 0 if gclids.empty?

      Estimation.where(gclid: gclids).update_all(colonne => Time.current)
    end

    private

    # Une virgule dans un libellé casserait le CSV : on n'entoure de guillemets
    # que ce qui en a besoin, Google acceptant les deux formes.
    def echapper(valeur)
      v = valeur.to_s
      v.match?(/[",\n]/) ? %("#{v.gsub('"', '""')}") : v
    end
  end
end
