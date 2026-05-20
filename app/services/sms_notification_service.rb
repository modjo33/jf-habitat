class SmsNotificationService
  def self.notify_new_lead(estimation)
    new(estimation).notify_new_lead
  end

  def initialize(estimation)
    @estimation = estimation
  end

  def notify_new_lead
    body = "🔔 JF Habitat: nouveau lead #{@estimation.nom} (#{@estimation.telephone}) " \
           "· #{format_eur(@estimation.total_ttc)} TTC · Réf #{@estimation.reference}"
    deliver(body)
  end

  private

  def deliver(body)
    unless configured?
      Rails.logger.info "[SMS] (DEV) #{body}"
      return
    end

    client.messages.create(
      from: ENV.fetch("TWILIO_FROM_NUMBER"),
      to:   ENV.fetch("ADMIN_PHONE_NUMBER"),
      body: body
    )
  rescue => e
    Rails.logger.warn "[SMS] Échec d'envoi: #{e.class} · #{e.message}"
  end

  def configured?
    %w[TWILIO_ACCOUNT_SID TWILIO_AUTH_TOKEN TWILIO_FROM_NUMBER ADMIN_PHONE_NUMBER].all? { |k| ENV[k].present? }
  end

  def client
    @client ||= Twilio::REST::Client.new(ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"])
  end

  def format_eur(amount)
    "#{format('%.0f', amount.to_f).gsub(/(\d)(?=(\d{3})+$)/, '\1 ')} €"
  end
end
