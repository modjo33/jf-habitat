class CreateSiteTexts < ActiveRecord::Migration[8.1]
  def change
    create_table :site_texts do |t|
      t.string  :key,         null: false
      t.text    :value,       null: false, default: ""
      t.text    :description, comment: "Notice pour l'admin : où le texte s'affiche"
      t.timestamps
    end
    add_index :site_texts, :key, unique: true
  end
end
