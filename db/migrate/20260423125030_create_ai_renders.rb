class CreateAiRenders < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_renders do |t|
      t.references :estimation, null: false, foreign_key: true
      t.string  :gamme, null: false
      t.string  :status, default: "pending", null: false
      t.integer :source_photo_index, default: 0, null: false
      t.text    :prompt_used
      t.text    :error_message
      t.string  :model_used
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :ai_renders, [:estimation_id, :gamme, :source_photo_index], name: "idx_ai_renders_unique"
    add_index :ai_renders, :status
  end
end
