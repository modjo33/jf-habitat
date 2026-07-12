class AddRatissageToMurs < ActiveRecord::Migration[8.1]
  def change
    add_column :murs, :ratissage_categorie, :string,  default: "aucun", null: false
    add_column :murs, :ratissage_forfait,   :decimal, precision: 8, scale: 2, default: "0.0"
  end
end
