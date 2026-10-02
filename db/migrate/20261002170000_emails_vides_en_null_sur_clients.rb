# Un e-mail "" bloquait l'index unique pour toute autre fiche sans e-mail
# (500 sur /admin/clients/38, 02/10/2026). Le modèle écrit désormais NULL.
class EmailsVidesEnNullSurClients < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE clients SET email = NULL WHERE btrim(email) = ''"
  end

  def down; end
end
