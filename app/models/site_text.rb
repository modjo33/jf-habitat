class SiteText < ApplicationRecord
  validates :key,   presence: true, uniqueness: true, format: { with: /\A[a-z0-9_.]+\z/ }
  validates :value, presence: true, allow_blank: true

  after_commit :expire_cache

  # Récupère la valeur d'une clé, ou nil si absente / vide.
  # Le helper site_text(key, fallback) se charge du fallback côté vue.
  def self.value_for(key)
    record = find_by(key: key.to_s)
    record&.value.presence
  end

  private

  def expire_cache
    Rails.cache.delete(["site_text", key.to_s])
  end
end
