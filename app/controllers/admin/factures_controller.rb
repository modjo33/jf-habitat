class Admin::FacturesController < Admin::BaseController
  before_action :set_facture, only: [:show, :edit, :update, :destroy, :pdf, :envoi, :envoyer,
                                     :marquer_payee, :regenerer]

  def index
    @annee = params[:annee].presence&.to_i || Date.current.year
    @factures = Facture.annee(@annee).includes(:client, :facture_lignes, :encaissements).recentes
    @total_annee    = @factures.sum(&:total)
    @encaisse_annee = @factures.sum(&:montant_encaisse)
    @impaye_annee   = @factures.reject { |f| f.statut == "annulee" }.sum(&:solde)
  end

  def show; end

  # Nouvelle facture : vierge, ou pré-remplie depuis un devis (?estimation_id=).
  def new
    @facture = if params[:estimation_id].present?
                 estimation = Estimation.find(params[:estimation_id])
                 Facture.depuis_estimation(estimation)
               else
                 Facture.new(date_emission: Date.current, client_id: params[:client_id])
               end
    @facture.facture_lignes.build(position: 0) if @facture.facture_lignes.empty?
  end

  def create
    @facture = Facture.new(facture_params)
    if @facture.save
      @facture.regenerer_pdf!
      redirect_to admin_facture_path(@facture), notice: "Facture #{@facture.numero} créée."
    else
      @facture.facture_lignes.build if @facture.facture_lignes.empty?
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @facture.facture_lignes.build(position: @facture.facture_lignes.size) if @facture.facture_lignes.empty?
  end

  def update
    if @facture.update(facture_params)
      @facture.regenerer_pdf!
      redirect_to admin_facture_path(@facture), notice: "Facture mise à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Une facture ÉMISE ne se supprime jamais : la numérotation FAC-AAAAMMJJ-NN
    # doit rester continue (un trou se voit immédiatement en contrôle fiscal).
    # Le bon geste comptable est l'annulation, qui garde le numéro.
    unless @facture.statut == "brouillon"
      return redirect_to admin_facture_path(@facture),
                         alert: "Une facture émise ne se supprime pas (trou de numérotation). " \
                                "Passe-la en « annulée » : elle garde son numéro et sort des totaux."
    end

    numero = @facture.numero
    @facture.destroy
    redirect_to admin_factures_path, notice: "Facture #{numero} supprimée."
  end

  # PDF servi depuis la base (Cloudinary ne délivre pas les PDF — cf. DevisDocument).
  def pdf
    send_data @facture.pdf_frais,
              filename: "#{@facture.numero}.pdf",
              type: "application/pdf",
              disposition: params[:download] ? "attachment" : "inline"
  end

  # Écran d'envoi : aperçu du PDF + message d'accompagnement modifiable.
  def envoi
    @facture.regenerer_pdf! unless @facture.pdf_a_jour?
  end

  def envoyer
    if @facture.client.email.blank?
      return redirect_to admin_facture_path(@facture),
                         alert: "Ce client n'a pas d'adresse e-mail. Ajoutez-la sur sa fiche."
    end

    LeadMailer.facture(@facture, params[:message]).deliver_now
    @facture.update(envoyee_at: Time.current,
                    statut: @facture.statut == "brouillon" ? "emise" : @facture.statut)
    @facture.client.touch(:derniere_interaction_at)
    redirect_to admin_facture_path(@facture),
                notice: "Facture #{@facture.numero} envoyée à #{@facture.client.email}."
  rescue => e
    Rails.logger.error "[Facture] envoi échoué : #{e.class} #{e.message}"
    redirect_to admin_facture_path(@facture),
                alert: "Échec de l'envoi de la facture. Réessayez."
  end

  # Solde encaissé en un clic : enregistre le règlement du reste dû au livre
  # des recettes (c'est lui qui fait basculer la facture en « Payée »), pas un
  # simple drapeau — sinon la facture et la compta divergeraient.
  def marquer_payee
    solde = @facture.solde
    if solde <= 0
      return redirect_to admin_facture_path(@facture), notice: "Cette facture est déjà soldée."
    end

    mode = params[:mode_reglement].presence_in(Encaissement::MODES.keys) || "virement"
    date = params[:date_encaissement].presence&.to_date || Date.current
    libelle = "Solde #{@facture.numero} — #{@facture.client.nom.to_s.strip}"

    Encaissement.create!(client: @facture.client, facture: @facture, montant: solde,
                         date_encaissement: date, mode_reglement: mode,
                         libelle: libelle, reference: @facture.numero)
    @facture.client.touch(:derniere_interaction_at)
    @facture.reload.regenerer_pdf!
    redirect_to admin_facture_path(@facture),
                notice: "Règlement de #{helpers.number_to_currency(solde, unit: '€', separator: ',', delimiter: ' ', format: '%n %u')} enregistré — facture soldée."
  rescue => e
    Rails.logger.error "[Facture] marquer payée : #{e.class} #{e.message}"
    redirect_to admin_facture_path(@facture), alert: "Impossible d'enregistrer le règlement."
  end

  def regenerer
    @facture.regenerer_pdf!
    redirect_to admin_facture_path(@facture), notice: "PDF régénéré."
  end

  private

  def set_facture
    @facture = Facture.find(params[:id])
  end

  def facture_params
    params.require(:facture).permit(
      :client_id, :estimation_id, :date_emission, :statut, :objet,
      :chantier_adresse, :conditions,
      facture_lignes_attributes: [:id, :section, :libelle, :description, :quantite,
                                  :unite, :prix_unitaire, :position, :_destroy]
    )
  end
end
