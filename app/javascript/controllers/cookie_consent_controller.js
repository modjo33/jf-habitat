import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  accept() { this.#set("granted") }
  deny()   { this.#set("denied") }

  #set(value) {
    const oneYear = 60 * 60 * 24 * 365
    document.cookie = `cookie_consent=${value}; path=/; max-age=${oneYear}; SameSite=Lax`
    this.element.remove()
    if (value === "granted") window.location.reload()
  }
}
