import { Controller } from "@hotwired/stimulus"

// Gère le toggle surface/dimensions et l'affichage des ouvertures selon la prestation
export default class extends Controller {
  static targets = ["prestation", "modeRadio", "modeSurface", "modeDimensions", "hauteurWrap", "ouvertures"]

  // Prestations pour lesquelles on applique la hauteur + déduction des ouvertures
  static mursPrestations = ["peinture_murs_reno", "peinture_murs_neuf", "placo_cloison"]

  connect() {
    this.toggleMode()
    this.onPrestationChange()
  }

  toggleMode() {
    const selected = this.modeRadioTargets.find(r => r.checked)?.value || "surface"
    if (selected === "dimensions") {
      this.modeSurfaceTarget.classList.add("hidden")
      this.modeDimensionsTarget.classList.remove("hidden")
    } else {
      this.modeSurfaceTarget.classList.remove("hidden")
      this.modeDimensionsTarget.classList.add("hidden")
    }
  }

  onPrestationChange() {
    if (!this.hasPrestationTarget) return
    const val = this.prestationTarget.value
    const isMurs = this.constructor.mursPrestations.includes(val)
    if (this.hasHauteurWrapTarget) {
      this.hauteurWrapTarget.style.display = isMurs ? "" : "none"
    }
    if (this.hasOuverturesTarget) {
      this.ouverturesTarget.classList.toggle("hidden", !isMurs)
    }
  }
}
