import { Controller } from "@hotwired/stimulus"

// Affiche, pendant la saisie d'un encaissement, la part de cotisations que ce
// montant emporte. Le piège du micro-entrepreneur est de considérer l'encaissé
// comme acquis : sur 1 000 €, 220 € ne sont pas à soi et tomberont deux mois
// plus tard. Autant le voir au moment où on saisit la somme.
//
// Affichage seul, aucune écriture : on peut donc écouter la frappe sans risque
// (contrairement aux autosaves, qui ne se déclenchent qu'au blur).
export default class extends Controller {
  static targets = ["montant", "sortie"]
  static values = { taux: Number }

  connect() { this.calculer() }

  calculer() {
    // Saisie française : « 979,80 » comme « 979.80 ».
    const brut = this.montantTarget.value.replace(",", ".").replace(/\s/g, "")
    const montant = parseFloat(brut)

    if (!isFinite(montant) || montant <= 0) {
      this.sortieTarget.textContent = ""
      return
    }

    const cotisations = montant * this.tauxValue / 100
    const net = montant - cotisations
    this.sortieTarget.innerHTML =
      `dont <strong>${this.eur(cotisations)}</strong> de cotisations URSSAF ` +
      `(${this.nombre(this.tauxValue)} %) — il te reste ${this.eur(net)}`
  }

  eur(v) {
    return `${v.toFixed(2).replace(".", ",")} €`
  }

  nombre(v) {
    return String(v).replace(".", ",")
  }
}
