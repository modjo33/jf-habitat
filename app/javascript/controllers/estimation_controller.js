import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "lines", "preview", "line", "codePostal", "etage", "ascenseur"]

  connect() {
    this.updatePreview()
  }

  addLine(event) {
    event.preventDefault()
    const template = document.getElementById("line-template")
    const index = new Date().getTime()
    const html = template.innerHTML.replace(/NEW_RECORD/g, index)
    document.getElementById("lines-container").insertAdjacentHTML("beforeend", html)
    this._renumber()
    this.updatePreview()
  }

  removeLine(event) {
    event.preventDefault()
    const line = event.target.closest(".estimation-line")
    const destroyInput = line.querySelector('input[name*="_destroy"]')
    if (destroyInput && line.querySelector('input[name*="[id]"]')) {
      destroyInput.value = "1"
      line.style.display = "none"
    } else {
      line.remove()
    }
    this._renumber()
    this.updatePreview()
  }

  _renumber() {
    const container = document.getElementById("lines-container")
    if (!container) return
    let n = 0
    container.querySelectorAll(".estimation-line").forEach(el => {
      if (el.style.display === "none") return
      n += 1
      const badge = el.querySelector(".line-number")
      if (badge) badge.textContent = n
    })
  }

  // Debounce : on attend que l'utilisateur arrête de saisir (350 ms) avant
  // d'appeler le serveur, pour éviter un appel par frappe.
  updatePreview() {
    clearTimeout(this._previewTimer)
    this._previewTimer = setTimeout(() => this._fetchPreview(), 350)
  }

  async _fetchPreview() {
    const lines = this._collectLines()
    const context = this._collectContext()
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const res = await fetch("/estimation/preview.json", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "application/json"
        },
        body: JSON.stringify({ lines, ...context })
      })

      if (!res.ok) return
      const data = await res.json()
      this._render(data)
    } catch (e) {
      console.warn("Preview update failed", e)
    }
  }

  _collectContext() {
    return {
      code_postal: document.querySelector('input[name="estimation[code_postal]"]')?.value || "",
      etage: document.querySelector('input[name="estimation[etage]"]')?.value || "0",
      ascenseur: document.querySelector('input[name="estimation[ascenseur]"]:checked')?.value || "true"
    }
  }

  _collectLines() {
    const container = document.getElementById("lines-container")
    if (!container) return []
    const lines = []
    container.querySelectorAll(".estimation-line").forEach(el => {
      if (el.style.display === "none") return
      const get = sel => el.querySelector(sel)?.value || ""
      const checked = sel => el.querySelector(sel)?.checked || false
      const modeRadio = el.querySelector('input[name*="[mode_saisie]"]:checked')
      lines.push({
        piece: get('input[name*="[piece]"]'),
        type_piece: get('select[name*="[type_piece]"]'),
        prestation: get('select[name*="[prestation]"]'),
        gamme: get('select[name*="[gamme]"]'),
        mode_saisie: modeRadio?.value || "surface",
        surface: get('input[name*="[surface]"]'),
        longueur: get('input[name*="[longueur]"]'),
        largeur: get('input[name*="[largeur]"]'),
        hauteur: get('input[name*="[hauteur]"]'),
        nb_portes: get('input[name*="[nb_portes]"]'),
        nb_fenetres: get('input[name*="[nb_fenetres]"]'),
        rebouchage_lourd: checked('input[name*="[rebouchage_lourd]"][value="1"]'),
        depose_ancien: checked('input[name*="[depose_ancien]"][value="1"]'),
        preparation_speciale: checked('input[name*="[preparation_speciale]"][value="1"]')
      })
    })
    return lines
  }

  _render(preview) {
    if (!this.hasPreviewTarget) return

    // Aucun prix n'est jamais affiché ici. Le devis chiffré (HT, TVA, TTC, PDF)
    // n'est révélé qu'après soumission des coordonnées (page show).
    if (!preview.lines || preview.lines.length === 0) {
      this.previewTarget.innerHTML = `
        <div class="text-center py-10 text-ink-light text-sm">
          <svg class="w-12 h-12 mx-auto text-ink-light/30 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
          </svg>
          Ajoutez une pièce pour commencer
        </div>`
      return
    }

    const linesHtml = preview.lines.map(l => `
      <div class="p-3 bg-sand rounded-lg text-sm border border-border-warm/50">
        <div class="font-semibold text-ink truncate">${this._escape(l.piece)}</div>
        <div class="text-xs text-ink-light truncate mt-0.5">${this._escape(l.prestation_label || "")} · ${this._escape(l.gamme_label || "")}</div>
        <div class="text-xs text-ink-light mt-1">
          <span class="inline-block bg-sand-dark px-2 py-0.5 rounded-full font-semibold text-ink">${l.surface} m²</span>
        </div>
      </div>`).join("")

    this.previewTarget.innerHTML = `
      <div class="space-y-2.5 mb-5 max-h-64 overflow-y-auto pr-1">${linesHtml}</div>
      <div class="space-y-2 py-4 border-y border-border-warm/60 text-sm">
        <div class="flex items-center justify-between">
          <span class="text-ink-light">Pièces / prestations</span>
          <span class="font-semibold text-ink">${preview.lines.length}</span>
        </div>
        <div class="flex items-center justify-between">
          <span class="text-ink-light">Surface totale</span>
          <span class="font-semibold text-ink">${preview.surface_totale} m²</span>
        </div>
      </div>
      <div class="mt-5 p-5 bg-ink rounded-2xl text-sand text-center">
        <div class="w-10 h-10 mx-auto mb-3 rounded-full bg-accent/20 border border-accent/40 flex items-center justify-center">
          <svg class="w-5 h-5 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
          </svg>
        </div>
        <div class="font-display text-base leading-snug mb-1.5">
          Votre devis détaillé<br>
          <em class="text-accent not-italic">après vos coordonnées.</em>
        </div>
        <p class="text-xs text-sand/65 leading-relaxed">
          Renseignez votre nom, email et téléphone ci-dessous — vous obtenez le total
          chiffré (HT, TVA, TTC) et le PDF immédiatement.
        </p>
      </div>`
  }

  _escape(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
