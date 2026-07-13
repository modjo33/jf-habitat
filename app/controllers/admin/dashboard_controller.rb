class Admin::DashboardController < Admin::BaseController
  def index
    @total_leads = Estimation.count
    @leads_semaine = Estimation.where(created_at: 7.days.ago..).count
    @leads_mois = Estimation.where(created_at: 1.month.ago..).count
    # CA : devis terrain signé s'il existe, sinon chiffrage web (voir Estimation.ca_montant).
    @ca_potentiel = Estimation.ca_montant + Client.sum(:montant_devis_manuel)
    @derniers_leads = Estimation.order(created_at: :desc).limit(10)
    @leads_par_statut = Estimation.group(:statut).count

    # CRM — devis acceptés (clients passés en « Gagné »)
    gagne_ids = Client.where(statut: "gagne").pluck(:id)
    @nb_devis_acceptes = gagne_ids.size
    @ca_gagne = Client.where(id: gagne_ids).sum(:montant_devis_manuel) +
                Estimation.where(client_id: gagne_ids).ca_montant

    # Compta — prochaine échéance URSSAF (trimestre précédent si pas encore
    # déclaré, sinon trimestre en cours).
    calcul = CalculDeclarations.new
    precedent = calcul.trimestre_precedent
    @prochaine_declaration = precedent.a_declarer? ? precedent : calcul.trimestre_courant

    @campagne = CampagneAds.instance

    # Agenda — RDV couvrant aujourd'hui (multi-jours inclus) + prochains.
    today = Date.current
    @rdvs_jour = Rdv.actifs
                    .where("starts_at <= ? AND COALESCE(ends_at, starts_at) >= ?", today.end_of_day, today.beginning_of_day)
                    .includes(:client).chrono
    @rdvs_a_venir = Rdv.actifs.where("starts_at > ?", today.end_of_day).includes(:client).chrono.limit(4)
  end
end
