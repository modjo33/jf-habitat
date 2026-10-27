# Critères complets saisis sur l'estimateur au moment où le visiteur laisse son
# numéro (pièces, dimensions, travaux, gamme, précisions, lignes chiffrées).
# Avant, la note ne gardait que le prix et une ligne de résumé : si le visiteur
# repartait sans envoyer le formulaire, tout le reste était perdu.
class AddDonneesToClientNotes < ActiveRecord::Migration[8.1]
  def change
    add_column :client_notes, :donnees, :jsonb
  end
end
