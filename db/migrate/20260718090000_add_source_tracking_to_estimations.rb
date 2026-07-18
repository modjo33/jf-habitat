class AddSourceTrackingToEstimations < ActiveRecord::Migration[8.1]
  def change
    add_column :estimations, :gclid,         :string
    add_column :estimations, :utm_source,    :string
    add_column :estimations, :utm_medium,    :string
    add_column :estimations, :utm_campaign,  :string
    add_column :estimations, :utm_term,      :string
    add_column :estimations, :utm_content,   :string
    add_column :estimations, :landing_page,  :string
    add_column :estimations, :referrer,      :string

    add_index :estimations, :gclid
    add_index :estimations, :utm_source
  end
end
