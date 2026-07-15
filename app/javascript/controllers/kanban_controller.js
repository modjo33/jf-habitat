import { Controller } from "@hotwired/stimulus"

// Kanban CRM : glisser une carte d'une colonne à l'autre change le statut
// commercial du client. Pointer Events → fonctionne à la souris ET au doigt
// (tablette), là où le drag HTML5 ne se déclenche pas au toucher.
export default class extends Controller {
  static values = { url: String } // gabarit d'URL avec le jeton __ID__

  // Démarre le glisser depuis la poignée d'une carte.
  start(event) {
    const card = event.target.closest("[data-client-id]")
    if (!card) return
    event.preventDefault()
    this.card         = card
    this.pointerId    = event.pointerId
    this.originColumn = card.closest("[data-kanban-column]")

    const rect  = card.getBoundingClientRect()
    this.offsetX = event.clientX - rect.left
    this.offsetY = event.clientY - rect.top

    this.ghost = card.cloneNode(true)
    this.ghost.style.cssText =
      `position:fixed;pointer-events:none;z-index:60;width:${rect.width}px;` +
      `opacity:.92;transform:rotate(1.5deg);box-shadow:0 14px 34px rgba(0,0,0,.20)`
    document.body.appendChild(this.ghost)
    card.style.opacity = "0.35"
    this.positionGhost(event)

    this.onMove = this.move.bind(this)
    this.onUp   = this.end.bind(this)
    window.addEventListener("pointermove", this.onMove)
    window.addEventListener("pointerup", this.onUp)
    window.addEventListener("pointercancel", this.onUp)
  }

  move(event) {
    if (event.pointerId !== this.pointerId) return
    this.positionGhost(event)
    const col = this.columnUnder(event)
    if (col !== this.hoverColumn) {
      this.hoverColumn?.classList.remove("ring-2", "ring-accent")
      this.hoverColumn = col
      if (col && col !== this.originColumn) col.classList.add("ring-2", "ring-accent")
    }
  }

  end() {
    window.removeEventListener("pointermove", this.onMove)
    window.removeEventListener("pointerup", this.onUp)
    window.removeEventListener("pointercancel", this.onUp)
    this.ghost?.remove()
    if (this.card) this.card.style.opacity = ""
    const col = this.hoverColumn
    this.hoverColumn?.classList.remove("ring-2", "ring-accent")
    this.hoverColumn = null

    if (col && col !== this.originColumn) this.drop(col)
    this.card = null
  }

  drop(col) {
    const list = col.querySelector("[data-kanban-list]")
    list.querySelector("[data-kanban-empty]")?.remove()
    list.appendChild(this.card)
    this.refreshCounts()
    this.persist(this.card.dataset.clientId, col.dataset.statut)
  }

  persist(id, statut) {
    fetch(this.urlValue.replace("__ID__", id), {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrf
      },
      body: JSON.stringify({ statut })
    }).catch(() => {})
  }

  // — helpers —
  positionGhost(event) {
    this.ghost.style.left = `${event.clientX - this.offsetX}px`
    this.ghost.style.top  = `${event.clientY - this.offsetY}px`
  }

  columnUnder(event) {
    this.ghost.style.display = "none"
    const el = document.elementFromPoint(event.clientX, event.clientY)
    this.ghost.style.display = ""
    return el?.closest("[data-kanban-column]")
  }

  refreshCounts() {
    this.element.querySelectorAll("[data-kanban-column]").forEach(col => {
      const badge = col.querySelector("[data-kanban-count]")
      if (badge) badge.textContent = col.querySelectorAll("[data-client-id]").length
    })
  }

  get csrf() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
