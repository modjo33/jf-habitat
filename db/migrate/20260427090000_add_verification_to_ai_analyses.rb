class AddVerificationToAiAnalyses < ActiveRecord::Migration[8.1]
  def change
    change_table :ai_analyses, bulk: true do |t|
      t.string   :nom
      t.string   :email
      t.string   :telephone
      t.string   :verification_code
      t.datetime :code_sent_at
      t.datetime :verified_at
      t.integer  :verification_attempts, default: 0, null: false
    end

    add_index :ai_analyses, :verified_at
  end
end
