# Analyse de rentabilité d'un devis — OUTIL INTERNE.
# Rien de ce que produit ce contrôleur ne doit atteindre un document client
# (cf. rake rentabilite:cloisonnement).
class Admin::DevisAnalysesController < Admin::BaseController
  before_action :set_estimation

  def update
    @analyse.update(analyse_params)
    @analyse.rafraichir!
    rendre_panneau
  end

  # Rejoue la photographie des taux sur les réglages du jour — action explicite,
  # jamais automatique : un devis établi ne doit pas bouger tout seul.
  def refiger
    @analyse.refiger_les_taux!
    @analyse.rafraichir!
    rendre_panneau(notice: "Taux mis à jour.")
  end

  private

  def set_estimation
    @estimation = Estimation.find(params[:id])
    @analyse = @estimation.analyse_rentabilite
  end

  def rendre_panneau(notice: nil)
    @estimation.reload
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("analyse_resultats",
          partial: "admin/devis/analyse_resultats",
          locals: { estimation: @estimation, analyse: @analyse.reload })
      end
      format.html { redirect_back fallback_location: admin_estimation_path(@estimation), notice: notice }
    end
  end

  def analyse_params
    params.require(:devis_analyse)
          .permit(:heures_saisies, :cout_materiaux_saisi, :autres_frais, :note)
  end
end
