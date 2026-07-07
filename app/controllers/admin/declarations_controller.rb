class Admin::DeclarationsController < Admin::BaseController
  def index
    @calcul = CalculDeclarations.new
    @reglages = @calcul.reglages
    @trimestre_courant   = @calcul.trimestre_courant
    @trimestre_precedent = @calcul.trimestre_precedent
    @mois_courant   = @calcul.france_travail
    @mois_precedent = @calcul.mois_precedent
    @seuils = @calcul.seuils
    @historique = DeclarationPeriode.order(annee: :desc, trimestre: :desc)
  end

  # Archive le trimestre avec le CA calculé au moment du clic.
  def marquer_declaree
    annee, trimestre = params.require(:annee).to_i, params.require(:trimestre).to_i
    calcul = CalculDeclarations.new
    t = calcul.construire_trimestre(annee, trimestre)
    DeclarationPeriode.create!(
      annee: annee, trimestre: trimestre,
      ca_declare: t.ca, cotisations_estimees: t.cotisations,
      declaree_le: Date.current
    )
    redirect_to admin_declarations_path, notice: "Déclaration T#{trimestre} #{annee} archivée (CA : #{helpers.number_to_currency(t.ca, unit: '€', separator: ',', delimiter: ' ', format: '%n %u')})."
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
                  :taux_cotisations, :taux_cfp, :taux_cma, :versement_liberatoire)
  end
end
