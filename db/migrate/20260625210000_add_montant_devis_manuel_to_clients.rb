class AddMontantDevisManuelToClients < ActiveRecord::Migration[8.1]
  # Montant d'un devis fait à la main (hors estimateur en ligne), pour que la valeur
  # du client compte dans le CA potentiel et le CA gagné du dashboard.
  def change
    add_column :clients, :montant_devis_manuel, :decimal, precision: 10, scale: 2
  end
end
