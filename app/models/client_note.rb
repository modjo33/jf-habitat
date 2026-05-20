class ClientNote < ApplicationRecord
  belongs_to :client

  validates :body, presence: true, length: { maximum: 5_000 }

  scope :recent, -> { order(created_at: :desc) }
end
