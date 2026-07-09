module ApplicationHelper
  # Singleton campagne Ads, tolérant si la table n'existe pas encore (fenêtre de
  # déploiement avant migration) → le bandeau admin ne casse jamais une page.
  def campagne_ads
    return @campagne_ads if defined?(@campagne_ads)
    @campagne_ads = CampagneAds.instance
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
    @campagne_ads = nil
  end

  # Conversion Google Ads « Demande de devis » (event manuel gtag, sans GTM).
  # Format ENV = "AW-XXXXXXXXX/LABEL" (send_to complet). Absent → conversion Ads
  # désactivée (fail-closed), le suivi GA4 generate_lead continue de tourner.
  def google_ads_lead_send_to
    ENV["GOOGLE_ADS_LEAD_SEND_TO"].presence
  end
end
