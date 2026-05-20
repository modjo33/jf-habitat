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

  private

  def number_to_currency(amount, unit: "€")
    "#{format('%.2f', amount.to_f).gsub('.', ',')} #{unit}"
  end
end
