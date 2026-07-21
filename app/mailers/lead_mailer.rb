class LeadMailer < ApplicationMailer
  default from: ENV.fetch("MAIL_FROM", "no-reply@jfhabitat.fr")

  def nouveau_lead(estimation)
    @estimation = estimation
    mail to: ENV.fetch("LEAD_NOTIFICATION_EMAIL", "contact@jfhabitat.fr"),
         subject: "🔔 Nouveau lead · #{estimation.nom} · #{number_to_currency(estimation.total_ttc, unit: '€')}"
  end

  def confirmation_client(estimation)
    @estimation = estimation
    mail to: estimation.email,
         subject: "Votre estimation JF Habitat · #{estimation.reference}"
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
