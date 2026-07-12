module DevisHelper
  # Affiche une valeur numérique, ou rien si elle vaut 0 — pour que les cases de
  # mesure soient vides par défaut (plus agréable à saisir sur tablette).
  def vide_si_zero(valeur)
    valeur.to_d.zero? ? nil : valeur
  rescue ArgumentError, TypeError
    valeur
  end

  # Formatage € à la française, cohérent avec le reste de l'admin.
  def eur(montant)
    number_to_currency(montant, unit: "€", separator: ",", delimiter: " ", format: "%n %u", precision: 2)
  end

  # Barème peinture (/admin/tarifs) sérialisé pour le JS : { "prestation|gamme" => prix }.
  # Permet à l'outil tablette de pré-remplir le prix quand on change type/gamme.
  def peinture_prix_json
    Tarif.actifs
         .where(prestation: Mur::PRESTATION_MAP.values)
         .each_with_object({}) { |t, h| h["#{t.prestation}|#{t.gamme}"] = t.prix_m2.to_f }
         .to_json
  end
end
