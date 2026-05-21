import { Controller } from "@hotwired/stimulus"

// Gère le toggle surface/dimensions et l'affichage des bons champs de dimension
// selon la prestation : murs → longueur × hauteur ; sols/plafonds → longueur × largeur.
export default class extends Controller {
  static targets = ["prestation", "modeRadio", "modeSurface", "modeDimensions", "largeurWrap", "hauteurWrap", "dimHint"]

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
    const isMurs = this.constructor.mursPrestations.includes(this.prestationTarget.value)

    // Murs : longueur (de mur) × hauteur → on masque la largeur, on montre la hauteur.
    // Sols/plafonds : longueur × largeur → l'inverse.
    if (this.hasLargeurWrapTarget) this.largeurWrapTarget.classList.toggle("hidden", isMurs)
    if (this.hasHauteurWrapTarget) this.hauteurWrapTarget.classList.toggle("hidden", !isMurs)

    if (this.hasDimHintTarget) {
      this.dimHintTarget.textContent = isMurs
        ? "Indiquez la longueur totale de mur à traiter × la hauteur sous plafond."
        : "Indiquez la longueur × la largeur de la surface au sol / plafond."
    }
  }
}
