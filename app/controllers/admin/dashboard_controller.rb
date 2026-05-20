class Admin::DashboardController < Admin::BaseController
  def index
    @total_leads = Estimation.count
    @leads_semaine = Estimation.where(created_at: 7.days.ago..).count
    @leads_mois = Estimation.where(created_at: 1.month.ago..).count
    @ca_potentiel = Estimation.sum(:total_ttc)
    @derniers_leads = Estimation.order(created_at: :desc).limit(10)
    @leads_par_statut = Estimation.group(:statut).count
  end
end
