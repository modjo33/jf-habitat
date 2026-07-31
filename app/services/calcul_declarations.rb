# Tous les calculs de la section Déclarations : URSSAF (trimestriel),
# France Travail (mensuel) et seuils annuels. Base : le CA ENCAISSÉ
# (table encaissements), jamais les devis.
class CalculDeclarations
  SEUIL_TVA          = 37_500 # franchise en base (art. 293 B CGI)
  SEUIL_TVA_MAJORE   = 41_250 # seuil majoré : TVA due dès le 1er jour de dépassement
  SEUIL_MICRO_BIC    = 77_700 # plafond du régime micro (prestations de services)
  SEUIL_COMPTE_DEDIE = 10_000 # compte bancaire dédié obligatoire si dépassé 2 ans de suite

  # Abattement micro-BIC prestations de services (50 %), puis France Travail
  # déduit 70 % du revenu retenu de l'ARE du mois.
  ABATTEMENT_BIC_SERVICES = 0.50
  PART_DEDUITE_ARE        = 0.70

  attr_reader :reglages

  def initialize(aujourd_hui = Date.current)
    @aujourd_hui = aujourd_hui
    @reglages = ReglageDeclaration.instance
  end

  # ---- URSSAF ----
  #
  # La périodicité est celle choisie à l'inscription (réglages) : mensuelle ou
  # trimestrielle. `numero` vaut le mois (1-12) ou le trimestre (1-4).

  Periode = Struct.new(:annee, :numero, :periodicite, :ca, :cotisations, :date_limite,
                       :declaration, :en_cours, keyword_init: true) do
    def mensuelle? = periodicite == "mensuelle"
    def libelle
      return I18n.l(Date.new(annee, numero, 1), format: "%B %Y").capitalize if mensuelle?

      "T#{numero} #{annee}"
    end
    def declaree?     = declaration.present?
    def a_declarer?   = !en_cours && !declaree?
    def en_retard?(ref = Date.current) = a_declarer? && ref > date_limite
  end

  def periodicite = reglages.periodicite_urssaf
  def mensuelle?  = reglages.mensuelle?

  def periode_courante
    construire_periode(@aujourd_hui.year, numero_de(@aujourd_hui), en_cours: true)
  end

  def periode_precedente
    date = mensuelle? ? (@aujourd_hui.beginning_of_month - 1.day)
                      : (@aujourd_hui.beginning_of_quarter - 1.day)
    construire_periode(date.year, numero_de(date), en_cours: false)
  end

  # Compatibilité : les anciens noms restent valides.
  alias_method :trimestre_courant, :periode_courante
  alias_method :trimestre_precedent, :periode_precedente

  def numero_de(date) = mensuelle? ? date.month : quarter_of(date)

  def construire_periode(annee, numero, en_cours: false)
    ca = mensuelle? ? Encaissement.mois(annee, numero).sum(:montant)
                    : Encaissement.trimestre(annee, numero).sum(:montant)
    Periode.new(
      annee: annee, numero: numero, periodicite: periodicite, ca: ca,
      cotisations: cotisations_estimees(ca),
      date_limite: date_limite(annee, numero),
      declaration: DeclarationPeriode.find_by(annee: annee, trimestre: numero, periodicite: periodicite),
      en_cours: en_cours
    )
  end

  def cotisations_estimees(ca)
    (ca * reglages.taux_global / 100).round(2)
  end

  # Échéance URSSAF : dernier jour du mois suivant la période, reporté au jour
  # ouvré suivant s'il tombe un week-end (vérifié sur le calendrier officiel :
  # septembre 2026 → 02/11, décembre 2026 → 01/02/2027).
  #
  # Début d'activité : l'URSSAF ne réclame rien les premiers mois puis regroupe
  # toutes les périodes écoulées à une même date. Tant qu'elle n'est pas passée,
  # cette date l'emporte — sinon le module annonce une échéance trop tôt.
  def date_limite(annee, numero)
    fin = mensuelle? ? Date.new(annee, numero, 1).end_of_month
                     : Date.new(annee, numero * 3, 1).end_of_month
    limite = jour_ouvre(fin.next_month.end_of_month)
    premiere = reglages.premiere_exigibilite_urssaf
    premiere.present? && limite < premiere ? premiere : limite
  end

  def jour_ouvre(date)
    date.on_weekend? ? date.next_weekday : date
  end

  # Échéancier complet : une ligne par période, du premier encaissement jusqu'à
  # la période en cours. C'est la vue qui manquait — deux cartes ne disent pas
  # ce qui arrive, ni combien il faut avoir mis de côté.
  def echeancier
    premier = Encaissement.minimum(:date_encaissement)
    return [] if premier.blank?

    debut = mensuelle? ? premier.beginning_of_month : premier.beginning_of_quarter
    fin   = mensuelle? ? @aujourd_hui.beginning_of_month : @aujourd_hui.beginning_of_quarter
    pas   = mensuelle? ? 1.month : 3.months

    periodes = []
    curseur = debut
    while curseur <= fin
      periodes << construire_periode(curseur.year, numero_de(curseur), en_cours: curseur == fin)
      curseur += pas
    end
    periodes
  end

  # Ce qu'il faut avoir de côté : les cotisations de tout ce qui est encaissé et
  # pas encore déclaré, période en cours comprise. C'est le chiffre qui manque
  # quand l'argent rentre et que la cotisation tombe deux mois plus tard.
  def a_provisionner
    echeancier.reject(&:declaree?).sum { |p| p.cotisations.to_d }
  end

  # La prochaine échéance à honorer (la plus proche parmi les non déclarées).
  def prochaine_echeance
    echeancier.reject(&:declaree?).min_by(&:date_limite)
  end

  # Part de cotisations que porte un encaissement donné — pour afficher, au
  # moment où l'argent rentre, ce qui n'est pas à soi.
  def cotisations_sur(montant)
    cotisations_estimees(montant.to_d)
  end

  # ---- France Travail (mois) ----

  MoisFT = Struct.new(:annee, :mois, :ca, :revenu_retenu, :deduction_are, :jours_non_indemnises, :are_estimee, keyword_init: true) do
    def libelle = I18n.l(Date.new(annee, mois, 1), format: "%B %Y").capitalize
  end

  def france_travail(date = @aujourd_hui)
    ca = Encaissement.mois(date.year, date.month).sum(:montant)
    revenu    = (ca * ABATTEMENT_BIC_SERVICES).round(2)
    deduction = (revenu * PART_DEDUITE_ARE).round(2)
    aj  = reglages.allocation_journaliere.to_f
    are = reglages.are_mensuelle.to_f
    MoisFT.new(
      annee: date.year, mois: date.month, ca: ca,
      revenu_retenu: revenu, deduction_are: deduction,
      jours_non_indemnises: aj.positive? ? (deduction / aj).ceil : 0,
      are_estimee: [are - deduction, 0].max.round(2)
    )
  end

  def mois_precedent = france_travail(@aujourd_hui.prev_month)

  # ---- Seuils annuels ----

  def ca_annuel(annee = @aujourd_hui.year)
    Encaissement.annee(annee).sum(:montant)
  end

  def seuils(annee = @aujourd_hui.year)
    ca = ca_annuel(annee)
    [
      { label: "Franchise TVA",              seuil: SEUIL_TVA,          note: "au-delà : facturation avec TVA (année suivante, ou immédiate si > #{SEUIL_TVA_MAJORE} €)" },
      { label: "Plafond micro-entreprise",   seuil: SEUIL_MICRO_BIC,    note: "au-delà : bascule au régime réel" },
      { label: "Compte bancaire dédié",      seuil: SEUIL_COMPTE_DEDIE, note: "obligatoire si dépassé 2 années de suite" }
    ].map { |s| s.merge(ca: ca, pourcentage: [(ca / s[:seuil] * 100).round, 100].min) }
  end

  private

  def quarter_of(date) = ((date.month - 1) / 3) + 1
end
