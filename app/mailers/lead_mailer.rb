class LeadMailer < ApplicationMailer
  default from: ENV.fetch("MAIL_FROM", "no-reply@jfhabitat.fr")

  # Notification interne. « Répondre » doit écrire AU CLIENT : c'est le geste
  # naturel en recevant l'alerte, et sans ça la réponse partait sur l'adresse
  # d'expédition du domaine, que le serveur entrant rejette.
  def nouveau_lead(estimation)
    @estimation = estimation
    mail to: ENV.fetch("LEAD_NOTIFICATION_EMAIL", "contact@jfhabitat.fr"),
         reply_to: estimation.email.presence,
         subject: "🔔 Nouveau lead · #{estimation.nom} · #{number_to_currency(estimation.total_ttc, unit: '€')}"
  end

  def confirmation_client(estimation)
    @estimation = estimation
    # Le CTA du wizard promet « Recevoir mon devis par e-mail » (renversement
    # du 28/08/2026) : le PDF doit donc être DANS ce mail, pas seulement
    # derrière un lien. Un PDF qui échoue ne prive pas le client du mail.
    begin
      pdf = DevisPdfGenerator.new(estimation).generate.render
      attachments["devis-jf-habitat-#{estimation.reference}.pdf"] = { mime_type: "application/pdf", content: pdf }
    rescue => e
      Rails.logger.error "[LeadMailer#confirmation_client] PDF non joint : #{e.class} · #{e.message}"
    end
    mail to: estimation.email,
         subject: "Votre devis estimatif JF Habitat · #{estimation.reference}"
  end

  # Message libre à un client, écrit depuis sa fiche. Il manquait tout un pan :
  # l'admin savait envoyer un devis et une facture, mais pas répondre à un
  # prospect, refuser un chantier hors zone ou demander un avis — autant de
  # messages qui partaient jusqu'ici de la boîte perso, hors de toute trace.
  def message_client(client, sujet, corps)
    @client = client
    @corps = corps.to_s
    mail to: client.email,
         cc: ENV.fetch("LEAD_NOTIFICATION_EMAIL", "contact@jfhabitat.fr"),
         subject: sujet.presence || "JF Habitat"
  end

  # Envoi du devis (PDF attaché) au client + copie interne.
  def devis_document(estimation, message = nil)
    @estimation = estimation
    @message = message.presence
    if estimation.devis_document&.data.present?
      attachments["devis-jf-habitat-#{estimation.reference}.pdf"] = {
        mime_type: "application/pdf", content: estimation.devis_document.data
      }
    end
    mail to: estimation.email,
         cc: ENV.fetch("LEAD_NOTIFICATION_EMAIL", "contact@jfhabitat.fr"),
         subject: "Votre devis · JF Habitat · #{estimation.reference}"
  end

  # Devis signé sur place : PDF joint, envoyé au client + copie interne.
  def devis_signe(estimation)
    @estimation = estimation
    pdf = estimation.devis_pdf_generator.generate.render
    attachments["devis-jf-habitat-#{estimation.reference}.pdf"] = { mime_type: "application/pdf", content: pdf }
    mail to: estimation.email,
         cc: ENV.fetch("LEAD_NOTIFICATION_EMAIL", "contact@jfhabitat.fr"),
         subject: "Votre devis signé · JF Habitat · #{estimation.reference}"
  end

  # Facture envoyée au client : PDF joint (depuis Facture#pdf_data, régénéré
  # si besoin), copie interne. `message` remplace le corps par défaut.
  def facture(facture, message = nil)
    @facture = facture
    @message = message.presence
    attachments["#{facture.numero}.pdf"] = {
      mime_type: "application/pdf", content: facture.pdf_frais
    }
    objet = facture.payee? ? "Votre facture acquittée" : "Votre facture"
    mail to: facture.client.email,
         cc: ENV.fetch("LEAD_NOTIFICATION_EMAIL", "contact@jfhabitat.fr"),
         subject: "#{objet} · JF Habitat · #{facture.numero}"
  end

  private

  def number_to_currency(amount, unit: "€")
    "#{format('%.2f', amount.to_f).gsub('.', ',')} #{unit}"
  end
end
