# Clients professionnels (sous-traitance, SCI…) : SIRET et n° de TVA
# intracommunautaire, imprimés sur les factures.
class AddSiretTvaToClients < ActiveRecord::Migration[8.0]
  def change
    add_column :clients, :siret, :string
    add_column :clients, :tva_intracom, :string
  end
end
