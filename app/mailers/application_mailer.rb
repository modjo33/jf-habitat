class ApplicationMailer < ActionMailer::Base
  # `contact@jfhabitat.fr` est une identité d'ENVOI (Resend). Le courrier
  # ENTRANT du domaine, lui, part chez IONOS (MX mx00/mx01.ionos.fr), qui
  # rejette l'adresse en 550 « mailbox unavailable » tant qu'aucune boîte n'y
  # est créée. Résultat : un client qui répond à son estimation, à son devis
  # ou à sa facture reçoit un rejet — et personne ne le sait, la réponse est
  # perdue en silence.
  #
  # `MAIL_REPLY_TO` renvoie ces réponses vers une boîte qui reçoit vraiment,
  # sans redéployer. Fail-closed : variable absente → aucun en-tête Reply-To,
  # comportement strictement inchangé. À retirer le jour où contact@ reçoit.
  default from: "from@example.com",
          reply_to: -> { ENV["MAIL_REPLY_TO"].presence }

  layout "mailer"
end
