class AddDetailsToTarifs < ActiveRecord::Migration[8.1]
  def change
    add_column :tarifs, :details, :text
  end
end
