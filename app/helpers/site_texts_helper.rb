module SiteTextsHelper
  # Récupère un texte éditable depuis SiteText, ou retombe sur le fallback
  # hardcodé si la clé n'existe pas ou que la valeur a été vidée.
  #
  # Usage :
  #   <%= site_text(:"home.hero.title_line1", "L'intérieur qui vous ressemble,") %>
  #
  # Le contenu est traité comme du TEXTE BRUT (échappé par défaut). Si Johan
  # ajoute des sauts de ligne dans l'admin, utilisez `simple_format` côté vue
  # pour les convertir en <br>.
  def site_text(key, fallback = "")
    value = Rails.cache.fetch(["site_text", key.to_s], expires_in: 5.minutes) do
      SiteText.value_for(key.to_s)
    end
    value.presence || fallback
  end
end
