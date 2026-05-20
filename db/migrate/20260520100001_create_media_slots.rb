class CreateMediaSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :media_slots do |t|
      t.string :key,         null: false
      t.text   :description, comment: "Notice pour l'admin : où la photo s'affiche"
      t.string :alt_text
      t.timestamps
    end
    add_index :media_slots, :key, unique: true
  end
end
