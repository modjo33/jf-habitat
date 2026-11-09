# Le numéro laissé sur l'estimateur (et la demande de rappel) est devenu le
# premier canal de contact depuis le 30/09, mais il ne gardait pas le clic
# Google Ads : Google voyait zéro conversion. On le garde sur la note pour
# pouvoir l'importer comme les estimations.
class AddGclidToClientNotes < ActiveRecord::Migration[8.1]
  def change
    add_column :client_notes, :gclid, :string
    add_column :client_notes, :ads_export_lead_at, :datetime
    add_index :client_notes, :gclid
  end
end
