# Les colonnes `email` et `telephone` étaient NOT NULL en base : hérité du
# tunnel public, où les coordonnées sont évidemment obligatoires. Mais un devis
# créé à la main dans l'admin (chantier de bouche-à-oreille) commence souvent
# avec un prénom et rien d'autre — la contrainte le rendait impossible.
#
# La présence reste exigée au niveau du MODÈLE pour les estimations issues du
# web (`unless: :manuel?`) : le tunnel public n'est pas assoupli, seule la base
# cesse d'imposer une règle qui ne vaut que pour lui.
class RendreCoordonneesFacultativesSurEstimations < ActiveRecord::Migration[8.1]
  def up
    change_column_null :estimations, :email, true
    change_column_null :estimations, :telephone, true
  end

  def down
    change_column_null :estimations, :email, false
    change_column_null :estimations, :telephone, false
  end
end
