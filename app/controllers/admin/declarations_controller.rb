class Admin::DeclarationsController < Admin::BaseController
  def index
    @calcul = CalculDeclarations.new
    @reglages = @calcul.reglages
    @trimestre_courant   = @calcul.periode_courante
    @trimestre_precedent = @calcul.periode_precedente
    @mois_courant   = @calcul.france_travail
    @mois_precedent = @calcul.mois_precedent
    @seuils = @calcul.seuils
    @echeancier      = @calcul.echeancier.reverse
    @a_provisionner  = @calcul.a_provisionner
    @prochaine       = @calcul.prochaine_echeance
    @historique = DeclarationPeriode.order(annee: :desc, trimestre: :desc)
  end

  # Archive la période avec le CA calculé au moment du clic.
  def marquer_declaree
    annee, numero = params.require(:annee).to_i, params.require(:trimestre).to_i
    calcul = CalculDeclarations.new
    t = calcul.construire_periode(annee, numero)
    DeclarationPeriode.create!(
      annee: annee, trimestre: numero, periodicite: calcul.periodicite,
      ca_declare: t.ca, cotisations_estimees: t.cotisations,
      declaree_le: Date.current
    )
    redirect_to admin_declarations_path, notice: "Déclaration #{t.libelle} archivée (CA : #{helpers.number_to_currency(t.ca, unit: '€', separator: ',', delimiter: ' ', format: '%n %u')})."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_declarations_path, alert: e.record.errors.full_messages.to_sentence
  end

  def annuler_declaration
    periode = DeclarationPeriode.find(params[:id])
    periode.destroy
    redirect_to admin_declarations_path, notice: "Déclaration #{periode.libelle} annulée (repasse en « à déclarer »)."
  end

  def update_reglages
    reglages = ReglageDeclaration.instance
    if reglages.update(reglages_params)
      redirect_to admin_declarations_path, notice: "Réglages enregistrés."
    else
      redirect_to admin_declarations_path, alert: reglages.errors.full_messages.to_sentence
    end
  end

  private

  def reglages_params
    params.require(:reglage_declaration)
          .permit(:are_mensuelle, :allocation_journaliere, :fin_droits_are,
                  :taux_cotisations, :taux_cfp, :taux_cma, :versement_liberatoire,
                  :periodicite_urssaf, :premiere_exigibilite_urssaf,
                  # Rentabilité des devis (outil interne)
                  :revenu_mensuel_cible, :jours_travailles_mois, :heures_par_jour,
                  :objectif_horaire_force, :deduire_are, :taux_impot,
                  :marge_securite_pct, :seuil_marge_alerte_pct,
                  :part_materiaux_max_pct, :heures_par_forfait)
  end
end
