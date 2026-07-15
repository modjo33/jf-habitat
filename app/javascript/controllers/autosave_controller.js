import { Controller } from "@hotwired/stimulus"

// Sauvegarde automatique d'un formulaire de devis terrain. Pensé pour tablette
// iPad : on ENREGISTRE à la sortie du champ (blur / change), jamais pendant la
// frappe — sinon le re-render serveur déplace le DOM sous le doigt et iOS fait
// sauter le scroll. Le calcul instantané des surfaces de ligne se fait en local.
export default class extends Controller {
  static values = {
    prices: { type: Object, default: {} },   // barème { "prestation|gamme" => prix }
    kind:   { type: String, default: "mur" }
  }
  static targets = ["prix", "chantier", "gamme", "dimA", "dimB", "rowSurface",
                    "qte", "pu", "unite", "lineTotal"]

  // Persiste (à la sortie du champ). Pas de re-render pendant la frappe.
  save() {
    this.element.requestSubmit()
  }

  // Feedback instantané pendant la frappe : recalcule la surface de la ligne
  // côté client (juste du texte, aucune structure DOM déplacée → pas de saut).
  liveRow() {
    if (!this.hasDimATarget || !this.hasDimBTarget || !this.hasRowSurfaceTarget) return
    const a = parseFloat(String(this.dimATarget.value).replace(",", ".")) || 0
    const b = parseFloat(String(this.dimBTarget.value).replace(",", ".")) || 0
    const s = (a * b).toFixed(2).replace(/\.?0+$/, "").replace(".", ",")
    this.rowSurfaceTarget.textContent = s === "" ? "0" : s
  }

  // Devis en lignes libres : total de la ligne (qté × prix, ou prix si forfait)
  // recalculé en direct pendant la frappe — juste du texte, pas de saut.
  liveLigne() {
    if (!this.hasLineTotalTarget) return
    const num = (el) => parseFloat(String(el?.value ?? "").replace(",", ".")) || 0
    const forfait = this.hasUniteTarget && this.uniteTarget.value === "forfait"
    const pu = num(this.puTarget)
    const total = forfait ? pu : num(this.qteTarget) * pu
    this.lineTotalTarget.textContent =
      total.toLocaleString("fr-FR", { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + " €"
    // Une ligne au forfait n'utilise pas la quantité : on la grise.
    if (this.hasQteTarget) this.qteTarget.disabled = forfait
  }

  // Sélectionne le contenu au focus : sur tablette, tu touches la case et ton
  // chiffre remplace directement la valeur.
  select(event) {
    const el = event.target
    requestAnimationFrame(() => { try { el.select() } catch (_) {} })
  }

  // Changement de type (réno/neuf) ou de gamme → repositionne le prix sur le
  // barème /admin/tarifs, puis enregistre.
  applyTarif() {
    if (this.hasPrixTarget && this.hasChantierTarget && this.hasGammeTarget) {
      const key = `${this.prestationKey()}|${this.gammeTarget.value}`
      const prix = this.pricesValue[key]
      if (prix !== undefined) this.prixTarget.value = prix
    }
    this.save()
  }

  prestationKey() {
    const neuf = this.chantierTarget.value === "neuf"
    if (this.kindValue === "plafond") return neuf ? "peinture_plafond_neuf" : "peinture_plafond"
    return neuf ? "peinture_murs_neuf" : "peinture_murs_reno"
  }

  // Changement de catégorie ponçage/rebouchage → pré-remplit le forfait, enregistre.
  prepCategory(event) {
    const select = event.target
    const input = document.getElementById(select.dataset.forfaitInput)
    const opt = select.selectedOptions[0]
    if (input && opt && opt.dataset.forfait !== undefined) {
      input.value = opt.dataset.forfait
    }
    this.save()
  }
}
