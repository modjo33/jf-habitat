import { Controller } from "@hotwired/stimulus"

// « Être rappelé » : ouvre/ferme le panneau, mesure l'ouverture côté serveur,
// et déclenche la conversion après un envoi réussi (le contenu arrive par
// turbo-stream, donc hors du turbo:load qu'écoute application.js).
// Vit sur <body> : tout data-action="rappel#open" de la page y remonte.
export default class extends Controller {
  static targets = ["panel"]

  open(event) {
    event?.preventDefault()
    if (!this.hasPanelTarget) return
    this.panelTarget.hidden = false
    document.body.classList.add("overflow-hidden")
    this.panelTarget.querySelector("input:not([type=hidden]):not([name='rappel[site_web]'])")?.focus({ preventScroll: true })
    this.#baliser("rappel_ouvert")
  }

  close(event) {
    event?.preventDefault()
    if (!this.hasPanelTarget) return
    this.panelTarget.hidden = true
    document.body.classList.remove("overflow-hidden")
  }

  keydown(event) {
    if (event.key === "Escape" && this.hasPanelTarget && !this.panelTarget.hidden) this.close()
  }

  submitted(event) {
    if (!event.detail?.success) return
    // Le partial de succès contient #lead-conversion-data ; laisser le
    // turbo-stream l'insérer avant de le lire.
    setTimeout(() => window.fireLeadConversion?.(), 150)
  }

  #baliser(etape) {
    const jeton = document.querySelector('meta[name="csrf-token"]')?.content
    fetch("/suivi-tunnel", {
      method: "POST",
      keepalive: true,
      headers: { "Content-Type": "application/json", "X-CSRF-Token": jeton || "" },
      body: JSON.stringify({ etape })
    }).catch(() => {})
  }
}
