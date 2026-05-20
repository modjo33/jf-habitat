import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  go(event) {
    if (event.target.closest("a, button, input, select, textarea, [data-no-row-link]")) return
    window.location = this.urlValue
  }
}
