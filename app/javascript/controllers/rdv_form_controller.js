import { Controller } from "@hotwired/stimulus"

// Pré-remplit l'adresse du RDV avec celle du client sélectionné (sans écraser
// une adresse déjà saisie).
export default class extends Controller {
  static targets = ["client", "adresse"]

  fillAdresse() {
    const opt = this.clientTarget.selectedOptions[0]
    const adr = opt && opt.dataset ? opt.dataset.adresse : ""
    if (adr && !this.adresseTarget.value.trim()) {
      this.adresseTarget.value = adr
    }
  }
}
