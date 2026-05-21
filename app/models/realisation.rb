class Realisation < ApplicationRecord
  METIERS = %w[peinture placo parquet].freeze

  has_one_attached :photo

  validates :legende, presence: true, length: { maximum: 200 }
  validates :metier,  presence: true, inclusion: { in: METIERS }
  validate  :photo_valide

  scope :active,   -> { where(active: true) }
  scope :ordered,  -> { order(position: :asc, created_at: :desc) }
  scope :for_metier, ->(m) { m.present? && METIERS.include?(m) ? where(metier: m) : all }

  before_create :set_default_position

  def metier_label
    metier.to_s.capitalize
  end

  # On sert le blob directement (redirige vers Cloudinary) : les variants Active
  # Storage (resize_to_fill) échouent avec le service Cloudinary (erreur 500).
  # Le CSS gère l'affichage ; les images uploadées sont déjà raisonnablement dimensionnées.
  def photo_url(w: 900, h: 1100)
    return nil unless photo.attached?
    Rails.application.routes.url_helpers.rails_blob_path(photo, only_path: true)
  end

  private

  def set_default_position
    return if position.to_i > 0
    self.position = (Realisation.maximum(:position) || 0) + 10
  end

  def photo_valide
    return unless photo.attached?
    if photo.blob.byte_size > 10.megabytes
      errors.add(:photo, "doit faire moins de 10 Mo")
    end
    unless %w[image/jpeg image/png image/webp image/heic image/avif].include?(photo.blob.content_type)
      errors.add(:photo, "doit être un JPG, PNG, WEBP, AVIF ou HEIC")
    end
  end
end
