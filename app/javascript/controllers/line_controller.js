import { Controller } from "@hotwired/stimulus"

// Gère le toggle surface/dimensions, les bons champs de dimension selon la
// prestation (murs → L×H ; sols/plafonds → L×l) et l'affichage des options
// (suppléments) selon le métier de la prestation choisie.
export default class extends Controller {
  static targets = ["prestation", "modeRadio", "modeSurface", "modeDimensions", "largeurWrap", "hauteurWrap", "dimHint", "options", "optionItem"]

  static mursPrestations = ["peinture_murs_reno", "peinture_murs_neuf", "placo_cloison"]

  // Métier (catégorie) de chaque prestation — pour afficher les bonnes options.
  static metiers = {
    peinture_murs_reno: "peinture", peinture_murs_neuf: "peinture",
    peinture_plafond: "peinture", peinture_plafond_neuf: "peinture",
    placo_cloison: "placo", placo_plafond: "placo", placo_bandes_enduit: "placo",
    parquet_stratifie: "parquet", parquet_contrecolle: "parquet", parquet_massif: "parquet"
  }

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
    const value = this.prestationTarget.value
    const isMurs = this.constructor.mursPrestations.includes(value)
    const metier = this.constructor.metiers[value]

    // Murs : longueur (de mur) × hauteur → masque la largeur, montre la hauteur.
    // Sols/plafonds : longueur × largeur → l'inverse.
    if (this.hasLargeurWrapTarget) this.largeurWrapTarget.classList.toggle("hidden", isMurs)
    if (this.hasHauteurWrapTarget) this.hauteurWrapTarget.classList.toggle("hidden", !isMurs)

    if (this.hasDimHintTarget) {
      this.dimHintTarget.textContent = isMurs
        ? "Indiquez la longueur totale de mur à traiter × la hauteur sous plafond."
        : "Indiquez la longueur × la largeur de la surface au sol / plafond."
    }

    // Options : chaque option s'affiche si son métier correspond à la prestation.
    let anyVisible = false
    this.optionItemTargets.forEach(item => {
      const metiers = (item.dataset.metiers || "").split(",")
      const show = metier && metiers.includes(metier)
      item.classList.toggle("hidden", !show)
      item.classList.toggle("flex", show)
      if (show) {
        anyVisible = true
      } else {
        const cb = item.querySelector('input[type="checkbox"]')
        if (cb) cb.checked = false
      }
    })
    if (this.hasOptionsTarget) this.optionsTarget.classList.toggle("hidden", !anyVisible)
  }
}
