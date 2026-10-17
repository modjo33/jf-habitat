# Brouillon de message libre sur la fiche client : on peut préparer un mail
# (par exemple pour Johan, depuis un script) et l'envoyer plus tard en un clic.
class AddBrouillonMessageToClients < ActiveRecord::Migration[8.0]
  def change
    add_column :clients, :brouillon_sujet, :string
    add_column :clients, :brouillon_corps, :text
  end
end
