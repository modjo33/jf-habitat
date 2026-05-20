class AddClientToEstimations < ActiveRecord::Migration[8.1]
  def change
    add_reference :estimations, :client, foreign_key: true, null: true
  end
end
