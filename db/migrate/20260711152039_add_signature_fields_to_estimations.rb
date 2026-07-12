class AddSignatureFieldsToEstimations < ActiveRecord::Migration[8.1]
  def change
    add_column :estimations, :devis_signataire,      :string
    add_column :estimations, :devis_signature_ip,    :string
    add_column :estimations, :devis_signe_envoye_at, :datetime  # horodatage de l'envoi du mail signé
  end
end
