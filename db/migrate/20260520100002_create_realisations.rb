class CreateRealisations < ActiveRecord::Migration[8.1]
  def change
    create_table :realisations do |t|
      t.string  :legende,  null: false
      t.string  :metier,   null: false, comment: "peinture | placo | parquet"
      t.integer :position, null: false, default: 0
      t.boolean :active,   null: false, default: true
      t.timestamps
    end
    add_index :realisations, :position
    add_index :realisations, [:active, :position]
  end
end
