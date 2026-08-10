import { Controller } from "@hotwired/stimulus"

// Menu de l'admin en tiroir sur téléphone. Au-dessus de md il est fixe et ce
// contrôleur ne fait rien : les classes responsive suffisent.
export default class extends Controller {
  static targets = ["panneau", "voile"]

  connect() {
    this.fermer()
    // Turbo garde le DOM entre deux pages : sans ça le tiroir resterait
    // ouvert par-dessus l'écran qu'on vient d'atteindre.
    this.onNavigation = () => this.fermer()
    document.addEventListener("turbo:load", this.onNavigation)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.onNavigation)
    document.body.classList.remove("overflow-hidden")
  }

  ouvrir() {
    this.panneauTarget.classList.remove("-translate-x-full")
    this.voileTarget.classList.remove("hidden")
    // Empêche la page de défiler derrière le tiroir.
    document.body.classList.add("overflow-hidden")
  }

  fermer() {
    this.panneauTarget.classList.add("-translate-x-full")
    this.voileTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  basculer() {
    this.panneauTarget.classList.contains("-translate-x-full") ? this.ouvrir() : this.fermer()
  }

  parEchap(event) {
    if (event.key === "Escape") this.fermer()
  }
}
