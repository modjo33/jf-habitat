class DevisDocument < ApplicationRecord
  belongs_to :estimation
  # `data` = octets du PDF du devis (stocké en base, pas sur Cloudinary qui
  # bloque la livraison des PDF).
end
