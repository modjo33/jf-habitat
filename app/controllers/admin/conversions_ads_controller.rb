class Admin::ConversionsAdsController < Admin::BaseController
  before_action :set_type

  def index
    @a_exporter = ConversionsAds.a_exporter(@type)
    @exportees  = ConversionsAds.deja_exportees(@type).reverse
    @sans_gclid = Estimation.where(gclid: [nil, ""])
                            .where("created_at >= ?", ConversionsAds::FENETRE_JOURS.days.ago).count

    respond_to do |format|
      format.html
      format.csv do
        send_data ConversionsAds.csv(@type, @a_exporter),
                  filename: ConversionsAds.nom_fichier(@type),
                  type: "text/csv; charset=utf-8"
      end
    end
  end

  # Marquage explicite APRÈS téléversement réussi : si l'import échoue chez
  # Google, rien n'a été marqué et le fichier reste régénérable à l'identique.
  def marquer
    lignes = ConversionsAds.a_exporter(@type)
    ConversionsAds.marquer!(@type, lignes)
    redirect_to admin_conversions_ads_path(type: @type),
                notice: "#{lignes.size} conversion#{'s' if lignes.size > 1} marquée#{'s' if lignes.size > 1} comme importée#{'s' if lignes.size > 1}."
  end

  private

  def set_type
    @type = ConversionsAds.type?(params[:type]) ? params[:type] : "lead"
    @conf = ConversionsAds::TYPES[@type]
  end
end
