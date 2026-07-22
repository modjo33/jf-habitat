# Recalage du barème interne sur les chantiers réellement réalisés.
# Le service PROPOSE, cet écran fait valider — jamais d'application silencieuse.
class Admin::CalibrageController < Admin::BaseController
  def index
    @calibrage = CalibrageBareme.new
  end

  def appliquer
    calibrage = CalibrageBareme.new
    n = calibrage.appliquer!(Array(params[:cles]).presence)
    if n.zero?
      redirect_to admin_calibrage_path, alert: "Aucun poste à mettre à jour."
    else
      # Les analyses existantes gardent leurs taux figés, mais leur verdict
      # dépend du barème : on le rejoue pour que les pastilles restent justes.
      Estimation.where("devis_total > 0").includes(:devis_analyse).find_each do |e|
        e.devis_analyse&.rafraichir!
      end
      redirect_to admin_calibrage_path,
                  notice: "#{n} poste(s) du barème mis à jour, pastilles recalculées."
    end
  end
end
