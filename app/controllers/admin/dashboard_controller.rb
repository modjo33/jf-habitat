class Admin::DashboardController < Admin::BaseController
  def index
    @total_leads = Estimation.count
    @leads_semaine = Estimation.where(created_at: 7.days.ago..).count
    @leads_mois = Estimation.where(created_at: 1.month.ago..).count
    # CA : devis terrain signé s'il existe, sinon chiffrage web (voir
    # Estimation.ca_montant). Client.ca_devis évite de compter deux fois un
    # chantier saisi à la fois en devis manuel et en devis terrain.
    @ca_potentiel = Client.ca_devis + Estimation.where(client_id: nil).ca_montant
    @derniers_leads = Estimation.order(created_at: :desc).limit(10)
    @leads_par_statut = Estimation.group(:statut).count

    # CRM — devis acceptés (clients passés en « Gagné »)
    gagnes = Client.where(statut: "gagne")
    @nb_devis_acceptes = gagnes.count
    @ca_gagne = Client.ca_devis(gagnes)
    # Ce qui est réellement rentré (livre des recettes) — à ne pas confondre
    # avec le CA gagné, qui n'est qu'un montant de devis accepté.
    @ca_encaisse = Encaissement.annee(Date.current.year).sum(:montant)
    @reste_a_encaisser = Facture.where.not(statut: "annulee").sum(&:solde)

    # Compta — prochaine échéance URSSAF (trimestre précédent si pas encore
    # déclaré, sinon trimestre en cours).
    calcul = CalculDeclarations.new
    # La plus proche échéance non déclarée, quelle que soit la périodicité ;
    # à défaut, la période en cours.
    @prochaine_declaration = calcul.prochaine_echeance || calcul.periode_courante
    # Ce qui n'est pas à soi : les cotisations sur tout l'encaissé non déclaré.
    @a_provisionner = calcul.a_provisionner

    @campagne = CampagneAds.instance

    # Agenda — RDV couvrant aujourd'hui (multi-jours inclus) + prochains.
    today = Date.current
    @rdvs_jour = Rdv.actifs
                    .where("starts_at <= ? AND COALESCE(ends_at, starts_at) >= ?", today.end_of_day, today.beginning_of_day)
                    .includes(:client).chrono
    @rdvs_a_venir = Rdv.actifs.where("starts_at > ?", today.end_of_day).includes(:client).chrono.limit(4)
  end
end
