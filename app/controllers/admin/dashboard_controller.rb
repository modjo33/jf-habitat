class Admin::DashboardController < Admin::BaseController
  def index
    @total_leads = Estimation.count
    @leads_semaine = Estimation.where(created_at: 7.days.ago..).count
    @leads_mois = Estimation.where(created_at: 1.month.ago..).count
    @ca_potentiel = Estimation.sum(:total_ttc) + Client.sum(:montant_devis_manuel)
    @derniers_leads = Estimation.order(created_at: :desc).limit(10)
    @leads_par_statut = Estimation.group(:statut).count

    # CRM — devis acceptés (clients passés en « Gagné »)
    gagne_ids = Client.where(statut: "gagne").pluck(:id)
    @nb_devis_acceptes = gagne_ids.size
    @ca_gagne = Client.where(id: gagne_ids).sum(:montant_devis_manuel) +
                Estimation.where(client_id: gagne_ids).sum(:total_ttc)
  end
end
