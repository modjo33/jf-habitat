import { Controller } from "@hotwired/stimulus"

// Pavé de signature au doigt (tablette). Dessine sur un <canvas>, permet
// d'effacer, et sérialise le tracé en PNG (data URL) dans un champ caché au
// moment de valider.
export default class extends Controller {
  static targets = ["canvas", "data"]

  connect() {
    this.canvas = this.canvasTarget
    this.resize()
    this.ctx = this.canvas.getContext("2d")
    this.ctx.lineWidth = 2.5
    this.ctx.lineCap = "round"
    this.ctx.lineJoin = "round"
    this.ctx.strokeStyle = "#0F2A44"
    this.drawing = false
    this.hasInk = false

    this._up = this.end.bind(this)
    this.canvas.addEventListener("pointerdown", this.start.bind(this))
    this.canvas.addEventListener("pointermove", this.draw.bind(this))
    window.addEventListener("pointerup", this._up)
  }

  resize() {
    const ratio = window.devicePixelRatio || 1
    const rect = this.canvas.getBoundingClientRect()
    this.canvas.width = rect.width * ratio
    this.canvas.height = rect.height * ratio
    this.canvas.getContext("2d").scale(ratio, ratio)
  }

  pos(e) {
    const r = this.canvas.getBoundingClientRect()
    return { x: e.clientX - r.left, y: e.clientY - r.top }
  }

  start(e) {
    e.preventDefault()
    this.drawing = true
    const p = this.pos(e)
    this.ctx.beginPath()
    this.ctx.moveTo(p.x, p.y)
  }

  draw(e) {
    if (!this.drawing) return
    e.preventDefault()
    const p = this.pos(e)
    this.ctx.lineTo(p.x, p.y)
    this.ctx.stroke()
    this.hasInk = true
  }

  end() {
    this.drawing = false
  }

  clear() {
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height)
    this.hasInk = false
  }

  // Au submit : refuse un pavé vide, sinon injecte le PNG dans le champ caché.
  submit(e) {
    if (!this.hasInk) {
      e.preventDefault()
      alert("Merci de faire signer le client avant de valider.")
      return
    }
    this.dataTarget.value = this.canvas.toDataURL("image/png")
  }

  disconnect() {
    window.removeEventListener("pointerup", this._up)
  }
}
