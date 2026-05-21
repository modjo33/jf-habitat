class MediaSlot < ApplicationRecord
  has_one_attached :image

  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validate  :image_valide

  def configured?
    image.attached?
  end

  # URL CDN Active Storage à utiliser dans les vues si l'admin a upload une image.
  # Sinon le helper PhotosHelper.stock_photo_url retombe sur Unsplash.
  # Blob direct (redirige vers Cloudinary) : les variants Active Storage échouent
  # avec le service Cloudinary. Les paramètres w/h sont conservés pour compat.
  def image_url(w: 1600, h: nil)
    return nil unless image.attached?
    Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
  end

  private

  def image_valide
    return unless image.attached?

    if image.blob.byte_size > 10.megabytes
      errors.add(:image, "doit faire moins de 10 Mo")
    end
    unless %w[image/jpeg image/png image/webp image/heic image/avif].include?(image.blob.content_type)
      errors.add(:image, "doit être un JPG, PNG, WEBP, AVIF ou HEIC")
    end
  end
end
