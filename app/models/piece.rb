class Piece < ApplicationRecord
  belongs_to :estimation
  has_many :murs, -> { order(:position, :id) }, dependent: :destroy
  accepts_nested_attributes_for :murs, allow_destroy: true

  validates :nom, presence: true
  validates :hauteur_sous_plafond, numericality: { greater_than_or_equal_to: 0 }

  before_save :recalculer

  def type_piece_label
    EstimationLine::TYPES_PIECE.dig(type_piece, :label) || type_piece
  end

  def total_calc
    murs.reject(&:marked_for_destruction?).sum { |m| m.total.to_d }.round(2)
  end

  private

  def recalculer
    self.total = total_calc
  end
end
