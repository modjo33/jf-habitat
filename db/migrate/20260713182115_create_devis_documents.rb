class CreateDevisDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :devis_documents do |t|
      t.references :estimation, null: false, foreign_key: true, index: { unique: true }
      t.binary :data
      t.timestamps
    end
  end
end
