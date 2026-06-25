class AllowNullEmailOnClients < ActiveRecord::Migration[8.1]
  # Un client créé manuellement (devis hors estimateur, bouche-à-oreille) peut
  # n'avoir qu'un téléphone. On lève la contrainte NOT NULL sur l'email ;
  # l'unicité/format restent garantis côté modèle quand il est renseigné.
  def change
    change_column_null :clients, :email, true
  end
end
