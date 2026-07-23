module ApplicationHelper
  # Singleton campagne Ads, tolérant si la table n'existe pas encore (fenêtre de
  # déploiement avant migration) → le bandeau admin ne casse jamais une page.
  def campagne_ads
    return @campagne_ads if defined?(@campagne_ads)
    @campagne_ads = CampagneAds.instance
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
    @campagne_ads = nil
  end

  # Téléphone de l'entreprise, affiché tel quel. Absent → les appels à
  # `business_phone_link` renvoient nil et l'appelant masque le bouton.
  def business_phone
    ENV["BUSINESS_PHONE"].presence
  end

  def business_phone_link
    business_phone && "tel:#{business_phone.gsub(/[^+\d]/, '')}"
  end

  # Conversion Google Ads « Demande de devis » (event manuel gtag, sans GTM).
  # Format ENV = "AW-XXXXXXXXX/LABEL" (send_to complet). Absent → conversion Ads
  # désactivée (fail-closed), le suivi GA4 generate_lead continue de tourner.
  def google_ads_lead_send_to
    ENV["GOOGLE_ADS_LEAD_SEND_TO"].presence
  end
end
