class Admin::CampagneAdsController < Admin::BaseController
  def update
    campagne = CampagneAds.instance
    attrs = campagne_params
    # Horodate dès qu'on touche à la dépense.
    attrs[:depense_maj_le] = Date.current if attrs.key?(:depense_cumulee)

    if campagne.update(attrs)
      redirect_to admin_root_path, notice: "Suivi campagne mis à jour."
    else
      redirect_to admin_root_path, alert: campagne.errors.full_messages.to_sentence
    end
  end

  private

  def campagne_params
    params.require(:campagne_ads)
          .permit(:nom, :budget_total, :depense_cumulee, :cout_journalier, :validation_deadline, :active)
  end
end
