class Rdv < ApplicationRecord
  belongs_to :client, optional: true
  belongs_to :estimation, optional: true

  # Type de RDV : libellé + couleur (hex, utilisée en style inline dans le calendrier).
  CATEGORIES = {
    "visite_metre" => { label: "Visite / métré", color: "#2563EB" },
    "chantier"     => { label: "Chantier",       color: "#E6752A" },
    "rappel"       => { label: "Rappel client",  color: "#16A34A" },
    "livraison"    => { label: "Livraison",      color: "#7C3AED" },
    "perso"        => { label: "Perso / admin",  color: "#64748B" },
    "autre"        => { label: "Autre",          color: "#0F2A44" }
  }.freeze

  STATUTS = { "prevu" => "Prévu", "fait" => "Fait", "annule" => "Annulé" }.freeze

  validates :titre, presence: true
  validates :starts_at, presence: true
  validates :categorie, inclusion: { in: CATEGORIES.keys }
  validates :statut, inclusion: { in: STATUTS.keys }
  validate :ends_after_starts

  scope :dans, ->(debut, fin) { where(starts_at: debut..fin) }
  scope :chrono, -> { order(:starts_at) }
  scope :a_venir, -> { where("starts_at >= ?", Time.current.beginning_of_day) }
  scope :actifs, -> { where.not(statut: "annule") }

  def categorie_label = CATEGORIES.dig(categorie, :label) || categorie
  def couleur         = CATEGORIES.dig(categorie, :color) || "#0F2A44"
  def statut_label    = STATUTS[statut] || statut

  def jour = starts_at.to_date
  def date_fin = (ends_at || starts_at).to_date
  def multi_jour? = date_fin > jour

  # Créneau horaire lisible ("09:00 → 11:00", "09:00", ou "Journée").
  def horaire
    return "Journée" if all_day?
    h = starts_at.strftime("%H:%M")
    ends_at.present? ? "#{h} → #{ends_at.strftime('%H:%M')}" : h
  end

  private

  def ends_after_starts
    return if ends_at.blank? || starts_at.blank?
    errors.add(:ends_at, "doit être après le début") if ends_at < starts_at
  end
end
