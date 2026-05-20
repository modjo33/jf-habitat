class Admin::MediaSlotsController < Admin::BaseController
  before_action :set_slot, only: [:update, :remove_image]

  def index
    @slots = MediaSlot.order(:key)
  end

  def update
    @slot.assign_attributes(slot_params)
    if @slot.save
      redirect_to admin_media_slots_path, notice: "Photo « #{@slot.key} » mise à jour."
    else
      redirect_to admin_media_slots_path, alert: @slot.errors.full_messages.to_sentence
    end
  end

  def remove_image
    @slot.image.purge_later if @slot.image.attached?
    redirect_to admin_media_slots_path, notice: "Photo « #{@slot.key} » retirée — retour au visuel par défaut."
  end

  private

  def set_slot
    @slot = MediaSlot.find(params[:id])
  end

  def slot_params
    params.require(:media_slot).permit(:alt_text, :image)
  end
end
