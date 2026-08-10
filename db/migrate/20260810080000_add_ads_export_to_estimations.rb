class AddAdsExportToEstimations < ActiveRecord::Migration[8.1]
  def change
    # Trace de ce qui a déjà été téléversé dans Google Ads, pour ne pas
    # réimporter deux fois la même conversion (Google compte les doublons).
    add_column :estimations, :ads_export_lead_at, :datetime
    add_column :estimations, :ads_export_vente_at, :datetime
  end
end
