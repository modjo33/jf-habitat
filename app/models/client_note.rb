class ClientNote < ApplicationRecord
  belongs_to :client

  validates :body, presence: true, length: { maximum: 5_000 }

  scope :recent, -> { order(created_at: :desc) }

  # Contact venu d'un clic Google Ads (numéro laissé sur l'estimateur ou
  # demande de rappel) : il s'exporte vers Google comme une estimation.
  scope :issues_de_google_ads, -> { where.not(gclid: [ nil, "" ]) }

  # Prix vu par le visiteur avant de laisser son numéro : le projet complet
  # s'il a été gardé, sinon la ligne « Devis affiché » de la note. 0 pour une
  # demande de rappel, qui n'a pas de chiffre.
  def total_ttc
    donnees&.dig("chiffrage", "total_ttc").to_d.nonzero? || body.to_s[/Devis affiché : (\d+)/, 1].to_d
  end

  def nom = client&.nom
  def reference = "#{body.to_s.start_with?('Demande de rappel') ? 'RAPPEL' : 'TEL'}-#{id}"
end
