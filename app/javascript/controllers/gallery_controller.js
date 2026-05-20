import { Controller } from "@hotwired/stimulus"

// Filtre la grille des réalisations par métier (peinture / placo / parquet / tous).
// Cible : data-controller="gallery" sur la section, data-gallery-target="pill|item|grid|empty".
export default class extends Controller {
  static targets = ["pill", "item", "grid", "empty"]

  connect() {
    this.applyFilter("tous")
  }

  filter(event) {
    const metier = event.params.filter
    this.applyFilter(metier)
  }

  applyFilter(metier) {
    this.pillTargets.forEach((pill) => {
      const active = pill.dataset.galleryFilterParam === metier
      pill.dataset.active = active ? "true" : "false"
    })

    let visibleCount = 0
    this.itemTargets.forEach((item) => {
      const show = metier === "tous" || item.dataset.metier === metier
      item.classList.toggle("hidden", !show)
      if (show) visibleCount += 1
    })

    if (this.hasEmptyTarget) {
      this.emptyTarget.classList.toggle("hidden", visibleCount > 0)
    }
  }
}
