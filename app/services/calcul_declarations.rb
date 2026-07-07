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

  # ---- URSSAF (trimestres) ----

  Trimestre = Struct.new(:annee, :numero, :ca, :cotisations, :date_limite, :declaration, :en_cours, keyword_init: true) do
    def libelle       = "T#{numero} #{annee}"
    def declaree?     = declaration.present?
    def a_declarer?   = !en_cours && !declaree?
    def en_retard?(ref = Date.current) = a_declarer? && ref > date_limite
  end

  def trimestre_courant  = construire_trimestre(@aujourd_hui.year, quarter_of(@aujourd_hui), en_cours: true)

  def trimestre_precedent
    date = @aujourd_hui.beginning_of_quarter - 1.day
    construire_trimestre(date.year, quarter_of(date), en_cours: false)
  end

  def construire_trimestre(annee, numero, en_cours: false)
    ca = Encaissement.trimestre(annee, numero).sum(:montant)
    Trimestre.new(
      annee: annee, numero: numero, ca: ca,
      cotisations: cotisations_estimees(ca),
      date_limite: date_limite(annee, numero),
      declaration: DeclarationPeriode.find_by(annee: annee, trimestre: numero),
      en_cours: en_cours
    )
  end

  def cotisations_estimees(ca)
    (ca * reglages.taux_global / 100).round(2)
  end

  # Échéance URSSAF trimestrielle : dernier jour du mois suivant le trimestre
  # (T1 → 30/04, T2 → 31/07, T3 → 31/10, T4 → 31/01 N+1).
  def date_limite(annee, trimestre)
    Date.new(annee, trimestre * 3, 1).end_of_month.next_month.end_of_month
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
