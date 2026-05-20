class DropAiTables < ActiveRecord::Migration[8.1]
  def up
    drop_table :ai_renders, if_exists: true
    drop_table :ai_analyses, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Suppression définitive des tables IA — voir migrations 20260423125028 / 20260423125030 / 20260427090000 si besoin de réintroduire."
  end
end
