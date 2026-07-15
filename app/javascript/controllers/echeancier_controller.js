import { Controller } from "@hotwired/stimulus"

// Échéancier de paiement : liste de versements (libellé + %). Le montant € de
// chaque ligne est calculé en direct (total du devis × %), une ligne sans %
// valant « le reste ». Ajout / suppression de lignes et modèles pré-remplis.
// L'enregistrement passe par le contrôleur `autosave` (même formulaire).
export default class extends Controller {
  static targets = ["rows", "row", "montant", "template", "warn"]
  static values  = { total: Number }

  connect() { this.live() }

  // Ajoute une ligne vierge (sans enregistrer : on attend la saisie + blur).
  add() {
    this.rowsTarget.appendChild(this.templateTarget.content.cloneNode(true))
    const rows = this.rowTargets
    rows[rows.length - 1]?.querySelector("input[name*='libelle']")?.focus()
    this.live()
  }

  // Supprime une ligne puis enregistre.
  remove(event) {
    event.target.closest("[data-echeancier-target='row']")?.remove()
    this.live()
    this.element.requestSubmit()
  }

  // Applique un modèle d'échéancier (remplace toutes les lignes) puis enregistre.
  applyPreset(event) {
    const opt = event.target.selectedOptions[0]
    if (!opt || !opt.value) return
    const echeances = JSON.parse(opt.dataset.echeances || "[]")
    this.rowTargets.forEach(r => r.remove())
    echeances.forEach(e => {
      const frag = this.templateTarget.content.cloneNode(true)
      frag.querySelector("input[name*='libelle']").value = e.libelle || ""
      frag.querySelector("input[name*='pct']").value     = (e.pct ?? "")
      this.rowsTarget.appendChild(frag)
    })
    event.target.selectedIndex = 0
    this.live()
    this.element.requestSubmit()
  }

  // Recalcule les montants € en direct (texte seul → aucun saut sur tablette).
  live() {
    const total = this.totalValue || 0
    const rows  = this.rowTargets
    const pctOf = (r) => parseFloat((r.querySelector("input[name*='pct']").value || "").replace(",", "."))

    const attribue = rows.reduce((s, r) => { const p = pctOf(r); return s + (isNaN(p) ? 0 : total * p / 100) }, 0)
    let sumPct = 0
    rows.forEach(r => {
      const p = pctOf(r)
      const montant = isNaN(p) ? (total - attribue) : (total * p / 100)
      if (!isNaN(p)) sumPct += p
      const el = r.querySelector("[data-echeancier-target='montant']")
      if (el) el.textContent = montant.toLocaleString("fr-FR", { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + " €"
    })
    if (this.hasWarnTarget) {
      this.warnTarget.textContent = sumPct > 100
        ? `⚠︎ Les versements chiffrés totalisent ${sumPct} % (plus de 100 %).`
        : ""
    }
  }
}
