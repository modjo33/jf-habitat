class Admin::SiteTextsController < Admin::BaseController
  def index
    @texts = SiteText.order(:key)
  end

  def update
    text = SiteText.find(params[:id])
    if text.update(text_params)
      redirect_to admin_site_texts_path, notice: "Texte « #{text.key} » mis à jour."
    else
      redirect_to admin_site_texts_path, alert: text.errors.full_messages.to_sentence
    end
  end

  private

  def text_params
    params.require(:site_text).permit(:value)
  end
end
