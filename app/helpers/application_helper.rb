module ApplicationHelper
  # Singleton campagne Ads, tolérant si la table n'existe pas encore (fenêtre de
  # déploiement avant migration) → le bandeau admin ne casse jamais une page.
  def campagne_ads
    return @campagne_ads if defined?(@campagne_ads)
    @campagne_ads = CampagneAds.instance
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
    @campagne_ads = nil
  end
end
