class CreateAiAnalyses < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_analyses do |t|
      t.string  :token, null: false
      t.string  :status, default: "pending", null: false
      t.references :estimation, foreign_key: true
      t.jsonb   :result, default: {}
      t.text    :error_message
      t.integer :photos_count, default: 0
      t.string  :model_used
      t.integer :input_tokens, default: 0
      t.integer :output_tokens, default: 0
      t.datetime :completed_at
      t.inet    :ip_address

      t.timestamps
    end

    add_index :ai_analyses, :token, unique: true
    add_index :ai_analyses, :status
    add_index :ai_analyses, :created_at
  end
end
