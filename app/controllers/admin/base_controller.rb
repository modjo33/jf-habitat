class Admin::BaseController < ApplicationController
  layout "admin"

  # Garde-fou anti-abus (par IP). Volontairement large : le concern compte CHAQUE
  # requête admin, pas seulement les échecs de login — un quota bas bloquerait Johan
  # en pleine navigation. La vraie protection reste le mot de passe fort (basic auth).
  rate_limit to: 300, within: 5.minutes, key: "admin_auth",
             response: -> { render plain: "Trop de requêtes. Réessayez dans quelques minutes.", status: :too_many_requests }

  before_action :authenticate_admin

  # Un enregistrement supprimé/inexistant ne doit pas afficher une 404 brute :
  # on renvoie vers la liste correspondante avec un message.
  rescue_from ActiveRecord::RecordNotFound do
    redirect_back fallback_location: admin_root_path,
                  alert: "Élément introuvable (il a peut-être été supprimé)."
  end

  private

  # En production, ADMIN_USER et ADMIN_PASSWORD DOIVENT être définis ;
  # à défaut on bloque l'accès plutôt que d'utiliser des credentials par défaut.
  def authenticate_admin
    expected_user = ENV["ADMIN_USER"]
    expected_pwd  = ENV["ADMIN_PASSWORD"]

    if Rails.env.production? && (expected_user.blank? || expected_pwd.blank?)
      Rails.logger.error "[Admin] ADMIN_USER ou ADMIN_PASSWORD non défini en production : accès refusé."
      return render plain: "Admin non configuré.", status: :service_unavailable
    end

    expected_user = expected_user.presence || "admin"
    expected_pwd  = expected_pwd.presence  || "jfhabitat2026"

    authenticate_or_request_with_http_basic("Admin JF Habitat") do |user, pwd|
      ActiveSupport::SecurityUtils.secure_compare(user.to_s, expected_user) &
        ActiveSupport::SecurityUtils.secure_compare(pwd.to_s, expected_pwd)
    end
  end
end
