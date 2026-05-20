class EnrichEstimationModels < ActiveRecord::Migration[8.1]
  def change
    # --- EstimationLine : dimensions, ouvertures, type pièce, options ---
    add_column :estimation_lines, :longueur, :decimal, precision: 6, scale: 2
    add_column :estimation_lines, :largeur,  :decimal, precision: 6, scale: 2
    add_column :estimation_lines, :hauteur,  :decimal, precision: 6, scale: 2
    add_column :estimation_lines, :nb_portes,     :integer, default: 0, null: false
    add_column :estimation_lines, :nb_fenetres,   :integer, default: 0, null: false
    add_column :estimation_lines, :type_piece,    :string,  default: "autre", null: false
    add_column :estimation_lines, :rebouchage_lourd,     :boolean, default: false, null: false
    add_column :estimation_lines, :depose_ancien,        :boolean, default: false, null: false
    add_column :estimation_lines, :preparation_speciale, :boolean, default: false, null: false
    add_column :estimation_lines, :mode_saisie, :string, default: "surface", null: false
    add_column :estimation_lines, :coef_applique, :decimal, precision: 5, scale: 3, default: 1.0

    # --- Estimation : étage, ascenseur, coefficients calculés, remise ---
    add_column :estimations, :etage,        :integer, default: 0, null: false
    add_column :estimations, :ascenseur,    :boolean, default: true, null: false
    add_column :estimations, :coef_region,  :decimal, precision: 5, scale: 3, default: 1.0
    add_column :estimations, :coef_etage,   :decimal, precision: 5, scale: 3, default: 1.0
    add_column :estimations, :remise_degressive, :decimal, precision: 5, scale: 3, default: 0.0
    add_column :estimations, :surface_totale,    :decimal, precision: 10, scale: 2, default: 0
  end
end
