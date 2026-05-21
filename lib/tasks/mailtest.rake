namespace :mailtest do
  desc "Envoie un email de test via SMTP en remontant les erreurs (diagnostic Resend)"
  task send: :environment do
    from = ENV["MAIL_FROM"]
    to   = ENV["LEAD_NOTIFICATION_EMAIL"]
    puts "MAILTEST from=#{from.inspect} to=#{to.inspect} smtp=#{ENV['SMTP_ADDRESS']}:#{ENV['SMTP_PORT']} user=#{ENV['SMTP_USERNAME'].inspect} pwd_len=#{ENV['SMTP_PASSWORD'].to_s.length}"
    begin
      mail = ActionMailer::Base.new.mail(
        from: from,
        to: to,
        subject: "Test diagnostic JF Habitat",
        body: "Test d'envoi diagnostic depuis la production."
      )
      mail.deliver! # bang : remonte l'erreur quel que soit raise_delivery_errors
      puts "MAILTEST_OK delivered"
    rescue => e
      puts "MAILTEST_FAIL #{e.class}: #{e.message}"
    end
  end
end
