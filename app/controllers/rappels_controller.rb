# « Être rappelé » : le contact le plus court possible, prénom + téléphone +
# une ligne sur les travaux. Décision du 09/09/2026 : sur ~110 clics Ads en
# 13 jours, 6 visiteurs ont vu leur devis en clair et AUCUN n'a laissé ses
# coordonnées, pendant que le seul chantier signé de la période venait d'un
# appel. Le canal voix convertit, le formulaire en six écrans non — on vend
# donc un rappel, l'estimateur reste disponible pour qui veut un chiffre.
#
# Le lead atterrit directement dans le CRM (Client statut « nouveau », action
# « Rappeler » datée d'aujourd'hui) : il apparaît dans la carte « À relancer »
# du tableau de bord sans rien inventer à côté.
class RappelsController < ApplicationController
  rate_limit to: 10, within: 1.hour, only: :create, key: "rappel_create"

  def create
    saisie = params.fetch(:rappel, {}).permit(:nom, :telephone, :travaux, :metier, :page, :site_web)

    # Pot de miel : un champ invisible rempli = robot. On répond « merci »
    # sans rien créer, pour ne pas lui apprendre qu'il a été vu.
    return repondre_succes(saisie[:nom], saisie[:telephone]) if saisie[:site_web].present?

    telephone = saisie[:telephone].to_s.gsub(/[[:space:].\-()]/, "")
    erreurs = []
    erreurs << "Merci d'indiquer votre prénom ou votre nom." if saisie[:nom].to_s.strip.length < 2
    erreurs << "Merci d'indiquer votre numéro de téléphone." if telephone.blank?
    return repondre_erreur(erreurs, saisie) if erreurs.any?

    # Même numéro déjà connu = même personne : une note sur sa fiche plutôt
    # qu'un doublon, la fiche garde l'historique.
    @client = Client.find_by(telephone: telephone) || Client.new(nom: saisie[:nom], telephone: telephone, statut: "nouveau")
    @client.statut = "nouveau" if @client.statut == "perdu"
    @client.prochaine_action = "Rappeler #{@client.telephone} (demande depuis le site)"
    @client.prochaine_action_date = Date.current
    @client.derniere_interaction_at = Time.current

    unless @client.save
      return repondre_erreur(@client.errors.full_messages, saisie)
    end

    travaux = saisie[:travaux].to_s.strip.first(500)
    contexte = contexte_lisible(saisie)
    @client.client_notes.create!(auteur: "Site", body: [ "Demande de rappel · #{contexte}", travaux.presence && "Travaux : #{travaux}" ].compact.join("\n"))

    suivre_etape("rappel", detail: saisie[:metier].presence || saisie[:page].to_s.presence)
    envoyer_sans_bloquer { LeadMailer.demande_rappel(@client, travaux, contexte).deliver_now }
    envoyer_sans_bloquer { SmsNotificationService.notify_rappel(@client, travaux) }

    # Le prénom TAPÉ, pas celui de la fiche : une fiche ancienne peut porter
    # un autre libellé, et c'est la personne devant l'écran qu'on remercie.
    repondre_succes(saisie[:nom].to_s.strip.presence || @client.nom, @client.telephone, client: @client)
  end

  private

  def repondre_succes(nom, telephone, client: nil)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("rappel-contenu", partial: "shared/rappel_succes",
                                                  locals: { nom: nom, telephone: telephone, client: client })
      end
      format.html { redirect_back fallback_location: root_path, notice: "C'est noté : je vous rappelle dans la journée." }
    end
  end

  def repondre_erreur(erreurs, saisie)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("rappel-contenu", partial: "shared/rappel_form",
                                                  locals: { erreurs: erreurs, valeurs: saisie.to_h,
                                                            metier: saisie[:metier], page: saisie[:page] }),
               status: :unprocessable_entity
      end
      format.html { redirect_back fallback_location: root_path, alert: erreurs.join(" ") }
    end
  end

  # « /peintre-bordeaux · Google Ads · mobile » — ce que Johan lit dans la
  # note et dans le mail pour savoir d'où vient la personne.
  def contexte_lisible(saisie)
    source = { "ads" => "Google Ads", "autre" => "campagne", "direct" => "direct" }[source_tunnel]
    [ saisie[:page].to_s.presence || request.referer.to_s.presence, source, appareil_tunnel ].compact.join(" · ")
  end

  def envoyer_sans_bloquer
    yield
  rescue => e
    Rails.logger.error "[RappelsController#create] notification échouée : #{e.class} · #{e.message}"
  end
end
