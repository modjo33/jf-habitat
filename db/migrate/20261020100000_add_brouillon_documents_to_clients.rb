# Pièces jointes retenues pour le brouillon de message (ids de client_documents).
class AddBrouillonDocumentsToClients < ActiveRecord::Migration[8.0]
  def change
    add_column :clients, :brouillon_document_ids, :integer, array: true, default: [], null: false
  end
end
