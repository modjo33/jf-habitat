# L'URSSAF laisse choisir entre déclaration MENSUELLE et TRIMESTRIELLE à
# l'inscription, et le module supposait le trimestre pour tout le monde. Johan
# déclare au mois : le tableau lui annonçait donc des échéances qui n'existent
# pas (« T2 à déclarer avant le 31/07 » alors que mai et juin étaient déjà
# déclarés) et masquait les vraies.
#
# La colonne `trimestre` de declaration_periodes devient le NUMÉRO de période
# (1-12 au mois, 1-4 au trimestre), qualifié par `periodicite`.
class AjouterPeriodiciteUrssaf < ActiveRecord::Migration[8.1]
  def up
    add_column :reglage_declarations, :periodicite_urssaf, :string, default: "mensuelle", null: false
    add_column :declaration_periodes, :periodicite, :string, default: "trimestrielle", null: false

    remove_index :declaration_periodes, column: %i[annee trimestre]
    add_index :declaration_periodes, %i[annee trimestre periodicite], unique: true,
              name: "index_declaration_periodes_sur_periode"
  end

  def down
    remove_index :declaration_periodes, name: "index_declaration_periodes_sur_periode"
    add_index :declaration_periodes, %i[annee trimestre], unique: true
    remove_column :declaration_periodes, :periodicite
    remove_column :reglage_declarations, :periodicite_urssaf
  end
end
