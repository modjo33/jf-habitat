# Un devis ne pouvait exister que rattaché à une estimation WEB : le client
# devait être passé par le formulaire en ligne. Impossible donc de chiffrer un
# chantier venu du bouche-à-oreille sans bricoler un faux lead.
#
# `origine` distingue les deux : "web" (soumission publique, validations du
# tunnel applicables) et "manuel" (créé depuis l'admin, où exiger un e-mail,
# un téléphone et une ligne de prestation n'a aucun sens).
class AjouterOrigineAuxEstimations < ActiveRecord::Migration[8.1]
  def change
    add_column :estimations, :origine, :string, default: "web", null: false
    add_index  :estimations, :origine
  end
end
