import { Controller } from "@hotwired/stimulus"

// Réordonnancement d'une liste par glisser-déposer via une poignée. Pointer
// Events → souris + tactile. Le DOM est réordonné en direct pendant le glisser,
// puis l'ordre complet des ids est persité (position = index). Le glisser reste
// dans le conteneur de départ (réordonnancement intra-section).
export default class extends Controller {
  static values = { url: String }

  start(event) {
    const item = event.target.closest("[data-sortable-item]")
    if (!item) return
    event.preventDefault()
    this.item      = item
    this.container = item.parentElement
    this.pointerId = event.pointerId

    const rect = item.getBoundingClientRect()
    this.offsetX = event.clientX - rect.left
    this.offsetY = event.clientY - rect.top

    this.ghost = item.cloneNode(true)
    this.ghost.style.cssText =
      `position:fixed;pointer-events:none;z-index:60;width:${rect.width}px;` +
      `opacity:.92;box-shadow:0 14px 34px rgba(0,0,0,.20)`
    document.body.appendChild(this.ghost)
    item.style.opacity = "0.3"
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
    const siblings = [...this.container.querySelectorAll("[data-sortable-item]")]
      .filter(el => el !== this.item)
    const after = siblings.find(el => {
      const r = el.getBoundingClientRect()
      return event.clientY < r.top + r.height / 2
    })
    if (after) this.container.insertBefore(this.item, after)
    else this.container.appendChild(this.item)
  }

  end() {
    window.removeEventListener("pointermove", this.onMove)
    window.removeEventListener("pointerup", this.onUp)
    window.removeEventListener("pointercancel", this.onUp)
    this.ghost?.remove()
    if (this.item) this.item.style.opacity = ""
    this.persist()
    this.item = null
  }

  persist() {
    const root = this.element.closest("[data-estimation-id]") || document
    const ids = [...root.querySelectorAll("[data-sortable-item]")]
      .map(el => el.dataset.sortableItem)
    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
      },
      body: JSON.stringify({ estimation_id: root.dataset?.estimationId, ids })
    }).catch(() => {})
  }

  positionGhost(event) {
    this.ghost.style.left = `${event.clientX - this.offsetX}px`
    this.ghost.style.top  = `${event.clientY - this.offsetY}px`
  }
}
