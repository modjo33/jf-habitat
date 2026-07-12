class AddPrestationFieldsToMurs < ActiveRecord::Migration[8.1]
  def change
    add_column :murs, :type_chantier, :string, default: "renovation", null: false
    add_column :murs, :gamme,         :string, default: "milieu",     null: false
  end
end
