# Franchise en base de TVA (art. 293 B du CGI) : l'entreprise ne collecte pas
# de TVA. L'estimateur en ligne en appliquait pourtant 10 %, annonçant au client
# un montant supérieur de 10 % à ce qui lui serait facturé.
#
# La colonne est conservée : le jour de l'assujettissement, il suffira de la
# repasser à 10 pour que tous les affichages (page devis, PDF, mails) reviennent.
# Les estimations déjà envoyées ne sont PAS retouchées — leur montant est celui
# que le client a reçu par mail.
class DefaultTvaAZeroSurEstimations < ActiveRecord::Migration[8.1]
  def up
    change_column_default :estimations, :tva_taux, from: "10.0", to: "0.0"
  end

  def down
    change_column_default :estimations, :tva_taux, from: "0.0", to: "10.0"
  end
end
