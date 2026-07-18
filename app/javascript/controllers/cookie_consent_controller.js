import { Controller } from "@hotwired/stimulus"

// Publie la hauteur du bandeau dans --cookie-banner-h : les écrans qui ont un
// CTA en bas (le wizard d'estimation) réservent cet espace, sinon le bandeau
// passe par-dessus le bouton et le tap part sur "Accepter" ou sur le lien
// politique de confidentialité — le visiteur est éjecté du tunnel.
export default class extends Controller {
  connect() {
    this.publishHeight()
    this._onResize = () => this.publishHeight()
    window.addEventListener("resize", this._onResize)
    window.addEventListener("orientationchange", this._onResize)
  }

  disconnect() {
    window.removeEventListener("resize", this._onResize)
    window.removeEventListener("orientationchange", this._onResize)
    this.#clearHeight()
  }

  // +16px de marge : sur les petits écrans (iPhone SE) le CTA arrivait encore à
  // 11px sous le bord haut du bandeau une fois scrollé en bas.
  publishHeight() {
    const h = Math.ceil(this.element.getBoundingClientRect().height) + 16
    document.documentElement.style.setProperty("--cookie-banner-h", `${h}px`)
  }

  accept() { this.#set("granted") }
  deny()   { this.#set("denied") }

  #set(value) {
    const oneYear = 60 * 60 * 24 * 365
    document.cookie = `cookie_consent=${value}; path=/; max-age=${oneYear}; SameSite=Lax`
    this.#clearHeight()
    this.element.remove()
    if (value === "granted") window.location.reload()
  }

  #clearHeight() {
    document.documentElement.style.setProperty("--cookie-banner-h", "0px")
  }
}
