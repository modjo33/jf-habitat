import { Controller } from "@hotwired/stimulus"

// Applique un modèle de conditions de paiement (acompte % + modalités) aux
// champs du formulaire, puis enregistre. Le formulaire porte aussi le
// contrôleur `autosave` ; requestSubmit() déclenche la sauvegarde.
export default class extends Controller {
  static targets = ["acompte", "texte"]

  apply(event) {
    const opt = event.target.selectedOptions[0]
    if (!opt || !opt.value) return
    if (this.hasAcompteTarget) this.acompteTarget.value = opt.dataset.acompte
    if (this.hasTexteTarget)   this.texteTarget.value   = opt.dataset.texte
    event.target.selectedIndex = 0        // remet l'intitulé « Modèle… »
    this.element.requestSubmit()          // → autosave (action conditions)
  }
}
