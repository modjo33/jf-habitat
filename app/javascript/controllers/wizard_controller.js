import { Controller } from "@hotwired/stimulus"

// Parcours d'estimation façon Typeform : une question par écran.
// - Écrans statiques : type de chantier, étage, ascenseur, nombre de pièces, contact.
// - Écrans dynamiques : pour chaque pièce → type, dimensions, travaux, gamme.
// À la soumission, on assemble les estimation_lines_attributes (1 par pièce × prestation,
// surface calculée, options auto) et on poste sur l'action create existante.
export default class extends Controller {
  static targets = ["step", "progressBar", "progressText", "back", "piecesContainer", "pieceTemplate", "recap", "lines", "nbPieces", "error", "loader", "devisTeaser", "devisRows", "submitBtn"]

  // Travaux génériques proposés → résolution vers une prestation réelle + type de surface.
  static TRAVAUX = [
    { id: "peinture_murs",       label: "Peinture des murs",     surface: "murs" },
    { id: "peinture_plafond",    label: "Peinture du plafond",   surface: "plafond" },
    { id: "placo_cloison",       label: "Cloison placo",         surface: "murs" },
    { id: "placo_plafond",       label: "Plafond placo",         surface: "plafond" },
    { id: "placo_bandes_enduit", label: "Bandes & enduit",       surface: "murs" },
    { id: "parquet_stratifie",   label: "Parquet stratifié",     surface: "sol" },
    { id: "parquet_contrecolle", label: "Parquet contrecollé",   surface: "sol" },
    { id: "parquet_massif",      label: "Parquet massif",        surface: "sol" }
  ]

  static TYPES_PIECE = [
    ["salon", "Salon / Séjour"], ["chambre", "Chambre"], ["cuisine", "Cuisine"],
    ["salle_de_bain", "Salle de bain / WC"], ["couloir", "Couloir / Entrée"],
    ["bureau", "Bureau"], ["autre", "Autre"]
  ]

  static GAMMES = [
    ["entree", "Entrée de gamme", "Finitions standards, matériaux courants"],
    ["milieu", "Milieu de gamme", "Bon rapport qualité-prix, finitions soignées"],
    ["haut", "Haut de gamme", "Matériaux premium, finitions impeccables"]
  ]

  connect() {
    this.index = 0
    this.show(0)
  }

  // ---- Navigation ---------------------------------------------------------

  // Lecture DOM synchrone (et qui ignore le contenu inerte du <template>) :
  // les cibles Stimulus insérées dynamiquement ne sont enregistrées qu'au tick
  // suivant, ce qui décalerait la navigation juste après generatePieces().
  get steps() { return Array.from(this.element.querySelectorAll(".wizard-step")) }

  show(i) {
    this.index = Math.max(0, Math.min(i, this.steps.length - 1))
    this.steps.forEach((s, idx) => s.classList.toggle("hidden", idx !== this.index))
    const step = this.steps[this.index]
    if (step.dataset.recap !== undefined) this.buildRecap()
    if (step.dataset.validate === "dimensions") this.configureDimensions(step)
    if (step.dataset.step === "contact") this.revealDevis()
    this.updateProgress()
    this.clearError()
    if (this.hasBackTarget) this.backTarget.classList.toggle("invisible", this.index === 0)
    const focusable = step.querySelector("input:not([type=hidden]), select, textarea, button[data-autofocus]")
    if (focusable) setTimeout(() => focusable.focus(), 60)
  }

  next() {
    const step = this.steps[this.index]
    if (!this.validateStep(step)) return
    // Génère les écrans "pièces" juste après le choix du nombre.
    if (step.dataset.step === "nb_pieces") this.generatePieces()
    this.go(1)
  }

  prev() { this.go(-1) }

  // Avance/recule en sautant les écrans non applicables (data-show-when).
  go(dir) {
    const steps = this.steps
    let i = this.index + dir
    while (i > 0 && i < steps.length - 1 && this.shouldSkip(steps[i])) i += dir
    this.show(i)
  }

  shouldSkip(step) {
    const cond = step.dataset.showWhen
    if (!cond) return false
    if (cond === "reno") return this.chantier() !== "renovation"
    if (cond === "peinture") return !this.projectHas("peinture")
    if (cond === "parquet") return !this.projectHas("parquet")
    return false
  }

  projectHas(prefix) {
    return [...this.element.querySelectorAll('input[name="piece_travaux"]:checked')].some(c => c.value.startsWith(prefix))
  }

  // Sélection d'une carte (choix unique) → enregistre + avance automatiquement.
  selectCard(event) {
    const card = event.currentTarget
    const group = card.closest("[data-card-group]")
    group.querySelectorAll("[data-card]").forEach(c => c.dataset.selected = "false")
    card.dataset.selected = "true"
    const input = group.querySelector("input[type=hidden]")
    if (input) input.value = card.dataset.value
    if (group.dataset.autoAdvance !== "false") setTimeout(() => this.next(), 180)
  }

  onKeydown(event) {
    if (event.key !== "Enter") return
    if (event.target.tagName === "TEXTAREA") return // laisser les retours à la ligne
    // Empêche la soumission native du formulaire (le seul submit est piloté manuellement).
    event.preventDefault()
    const step = this.steps[this.index]
    if (!step || step.dataset.noEnter !== undefined) return
    this.next()
  }

  // Nombre d'écrans par pièce dans le <template> (type, travaux, dimensions, gamme).
  get screensPerPiece() {
    if (this._spp === undefined) {
      const frag = this.hasPieceTemplateTarget ? this.pieceTemplateTarget.content : null
      this._spp = frag ? frag.querySelectorAll(".wizard-step").length : 4
    }
    return this._spp
  }

  // Total anticipé : tant que les écrans "pièce" ne sont pas générés, on les
  // projette à partir du nombre saisi. Sans ça le dénominateur explose d'un coup
  // après l'écran nb_pieces (3/10 → 4/22) et la barre RECULE — abandon assuré
  // juste avant la partie la plus longue du formulaire.
  get projectedTotal() {
    const current = this.steps.length
    const generated = this.element.querySelectorAll("[data-piece-index]").length
    if (generated > 0) return current
    const nb = Math.max(1, Math.min(parseInt(this.hasNbPiecesTarget ? this.nbPiecesTarget.value || "1" : "1", 10) || 1, 12))
    return current + nb * this.screensPerPiece
  }

  updateProgress() {
    const total = this.projectedTotal
    const pct = Math.round((this.index / Math.max(1, total - 1)) * 100)
    if (this.hasProgressBarTarget) this.progressBarTarget.style.width = `${pct}%`
    if (this.hasProgressTextTarget) this.progressTextTarget.textContent = `${this.index + 1} / ${total}`
  }

  // ---- Validation ---------------------------------------------------------

  validateStep(step) {
    const kind = step.dataset.validate
    if (!kind) return true
    if (kind === "card") {
      const input = step.querySelector("input[type=hidden]")
      if (!input || !input.value) return this.fail(step, "Choisissez une option.")
    } else if (kind === "number") {
      const input = step.querySelector("input[type=number]")
      if (!input || !(parseFloat(input.value) > 0)) return this.fail(step, "Entrez une valeur valide.")
    } else if (kind === "dimensions") {
      const groups = [...step.querySelectorAll("[data-dim-group]")].filter(g => !g.classList.contains("hidden"))
      const ok = groups.every(g => [...g.querySelectorAll("[data-dim]")].every(inp => parseFloat(inp.value) > 0))
      if (!ok) return this.fail(step, "Renseignez les dimensions demandées.")
    } else if (kind === "travaux") {
      const any = step.querySelectorAll("input[type=checkbox]:checked").length > 0
      if (!any) return this.fail(step, "Sélectionnez au moins un type de travaux.")
    } else if (kind === "contact") {
      const nom = step.querySelector('[name="estimation[nom]"]')?.value.trim()
      const email = step.querySelector('[name="estimation[email]"]')?.value.trim()
      const tel = step.querySelector('[name="estimation[telephone]"]')?.value.trim()
      if (!nom || !email || !tel) return this.fail(step, "Nom, email et téléphone sont requis.")
    }
    return true
  }

  fail(step, msg) {
    this.clearError()
    const box = step.querySelector("[data-wizard-target='error']") || (this.hasErrorTarget && this.errorTarget)
    if (box) { box.textContent = msg; box.classList.remove("hidden") }
    return false
  }

  clearError() {
    this.element.querySelectorAll("[data-wizard-target='error']").forEach(e => { e.textContent = ""; e.classList.add("hidden") })
  }

  // ---- Génération des écrans "pièces" -------------------------------------

  generatePieces() {
    const nb = Math.max(1, Math.min(parseInt(this.nbPiecesTarget.value || "1", 10), 12))
    this.piecesContainerTarget.innerHTML = ""
    for (let i = 1; i <= nb; i++) {
      const html = this.pieceTemplateTarget.innerHTML
        .replace(/__N__/g, i)
      this.piecesContainerTarget.insertAdjacentHTML("beforeend", html)
    }
  }

  // ---- Récap (sans prix) --------------------------------------------------

  // Récap sans prix. Les options "auto" sont rendues comme des cases à cocher,
  // pré-cochées selon le type de chantier mais modifiables : ces cases sont
  // ensuite la source de vérité pour buildLines.
  buildRecap() {
    const reno = this.chantier() === "renovation"
    const pieces = this.collectPieces()
    let html = ""
    pieces.forEach(p => {
      const travauxLabels = p.travaux.map(t => this.constructor.TRAVAUX.find(x => x.id === t)?.label).filter(Boolean)
      const dimParts = []
      if (p.mursL > 0 && p.mursH > 0) dimParts.push(`murs ${p.mursL}×${p.mursH} m`)
      if (p.solL > 0 && p.soll > 0) dimParts.push(`sol ${p.solL}×${p.soll} m`)
      const dims = dimParts.join(" · ")
      const hasPeinture = p.travaux.some(t => t.startsWith("peinture"))
      const hasParquet = p.travaux.some(t => t.startsWith("parquet"))
      let opts = ""
      if (hasPeinture) opts += this.optionCheckbox(p.index, "poncage_peinture", "Ponçage / préparation des supports", reno)
      if (hasParquet) {
        opts += this.optionCheckbox(p.index, "depose_evacuation", "Dépose & évacuation de l'ancien revêtement", reno)
        opts += this.optionCheckbox(p.index, "poncage", "Ponçage + vitrification du parquet", false)
      }
      html += `
        <div class="p-5 bg-sand rounded-xl border border-border-warm/60 mb-3 text-left">
          <div class="font-display text-lg text-ink">${this.escape(p.typeLabel)} <span class="text-ink-light text-sm font-body">· ${this.escape(dims)}</span></div>
          <div class="text-sm text-ink-soft mt-1">${travauxLabels.map(l => this.escape(l)).join(" · ")}</div>
          <div class="text-xs font-semibold text-accent uppercase tracking-wide mt-2">Gamme : ${this.escape(p.gammeLabel)}</div>
          ${opts ? `<div class="mt-3 pt-3 border-t border-border-warm/60 space-y-2">${opts}</div>` : ""}
        </div>`
    })
    this.recapTarget.innerHTML = html || "<p class='text-ink-light'>Aucune pièce.</p>"
  }

  optionCheckbox(pieceIndex, key, label, checked) {
    return `
      <label class="flex items-center gap-2.5 cursor-pointer text-sm text-ink-soft">
        <input type="checkbox" data-opt-piece="${pieceIndex}" data-opt-key="${key}" ${checked ? "checked" : ""}
               class="w-4 h-4 rounded border-border-warm text-accent focus:ring-accent/40">
        ${this.escape(label)}
      </label>`
  }

  optionEnabled(pieceIndex, key) {
    const cb = this.element.querySelector(`[data-opt-piece="${pieceIndex}"][data-opt-key="${key}"]`)
    return cb ? cb.checked : false
  }

  // ---- Devis flouté + loader -------------------------------------------

  // À l'arrivée sur l'écran coordonnées : on "calcule" (loader) puis on dévoile
  // un devis dont les montants restent floutés tant que le formulaire n'est pas
  // envoyé. Le devis chiffré réel n'est rendu qu'après soumission (page show).
  revealDevis() {
    if (!this.hasLoaderTarget || !this.hasDevisTeaserTarget) return
    this.buildDevisTeaser()
    this.loaderTarget.classList.remove("hidden")
    this.devisTeaserTarget.classList.add("hidden")
    clearTimeout(this._loaderTimer)
    this._loaderTimer = setTimeout(() => {
      this.loaderTarget.classList.add("hidden")
      this.devisTeaserTarget.classList.remove("hidden")
    }, 1500)
  }

  buildDevisTeaser() {
    const pieces = this.collectPieces()
    let rows = ""
    pieces.forEach(p => {
      const labels = p.travaux.map(t => this.constructor.TRAVAUX.find(x => x.id === t)?.label).filter(Boolean).join(", ")
      rows += `
        <div class="flex items-center justify-between gap-4 py-1.5 border-b border-border-warm/50 last:border-0">
          <span class="text-sm text-ink-soft">${this.escape(p.typeLabel)} · ${this.escape(labels)}</span>
          <span class="devis-blur font-semibold text-ink">•••• €</span>
        </div>`
    })
    rows += `
      <div class="flex items-center justify-between gap-4 pt-3 mt-1">
        <span class="font-display text-lg text-ink">Total estimé</span>
        <span class="devis-blur font-display text-xl text-accent">• ••• €</span>
      </div>`
    this.devisRowsTarget.innerHTML = rows
  }

  // ---- Assemblage + soumission -------------------------------------------

  submitForm(event) {
    if (event) event.preventDefault()
    const step = this.steps[this.index]
    if (!this.validateStep(step)) return
    this.buildPrecisions()
    this.buildLines()
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = true
      this.submitBtnTarget.classList.add("opacity-70", "pointer-events-none")
      this.submitBtnTarget.innerHTML = '<span class="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin"></span> Génération du devis…'
    }
    this.element.requestSubmit()
  }

  // Compile les réponses "précisions" dans le champ message (visible côté admin
  // et dans l'email de lead) — pas de colonne dédiée nécessaire.
  buildPrecisions() {
    const val = name => this.element.querySelector(`[name="${name}"]`)?.value?.trim()
    const rows = [
      ["État des surfaces", val("prec_etat")],
      ["Type de peinture", val("prec_peinture")],
      ["Teintes", val("prec_teintes")],
      ["Revêtement de sol actuel", val("prec_sol")],
      ["Logement", val("prec_occupe")],
      ["Meubles", val("prec_meubles")],
      ["Hauteur sous plafond > 2,70 m", val("prec_hauteur")],
      ["Accès & stationnement", val("prec_acces")],
      ["Profil", val("prec_profil")],
      ["Origine du contact", val("prec_source")]
    ].filter(r => r[1])
    if (!rows.length) return
    const summary = "— Précisions du formulaire —\n" + rows.map(r => `• ${r[0]} : ${r[1]}`).join("\n")
    const ta = this.element.querySelector('[name="estimation[message]"]')
    if (ta) ta.value = ta.value.trim() ? `${summary}\n\n${ta.value.trim()}` : summary
  }

  buildLines() {
    const reno = this.chantier() === "renovation"
    const pieces = this.collectPieces()
    this.linesTarget.innerHTML = ""
    let n = 0
    pieces.forEach(p => {
      p.travaux.forEach(travailId => {
        const t = this.constructor.TRAVAUX.find(x => x.id === travailId)
        if (!t) return
        const prestation = this.resolvePrestation(t, reno)
        const surface = this.computeSurface(t.surface, p)
        const isPeinture = prestation.startsWith("peinture")
        const isParquet = prestation.startsWith("parquet")
        this.addLine(n, {
          piece: p.typeLabel,
          type_piece: p.type,
          prestation: prestation,
          gamme: p.gamme,
          mode_saisie: "surface",
          surface: surface.toFixed(2),
          poncage: (isParquet && this.optionEnabled(p.index, "poncage")) ? "1" : "0",
          poncage_peinture: (isPeinture && this.optionEnabled(p.index, "poncage_peinture")) ? "1" : "0",
          depose_evacuation: (isParquet && this.optionEnabled(p.index, "depose_evacuation")) ? "1" : "0"
        })
        n++
      })
    })
  }

  addLine(i, attrs) {
    const base = `estimation[estimation_lines_attributes][${i}]`
    Object.entries(attrs).forEach(([k, v]) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = `${base}[${k}]`
      input.value = v
      this.linesTarget.appendChild(input)
    })
  }

  // ---- Helpers métier -----------------------------------------------------

  chantier() {
    return this.element.querySelector('[name="estimation[type_chantier]"]')?.value || "renovation"
  }

  collectPieces() {
    const blocks = {}
    this.element.querySelectorAll("[data-piece-index]").forEach(step => {
      const i = step.dataset.pieceIndex
      blocks[i] ||= step
    })
    // Chaque pièce a 4 écrans tagués data-piece-index ; on lit tous les inputs par index.
    const indexes = [...new Set([...this.element.querySelectorAll("[data-piece-index]")].map(s => s.dataset.pieceIndex))]
    return indexes.map(i => {
      const scope = `[data-piece-index="${i}"]`
      const typeInput = this.element.querySelector(`${scope} input[name="piece_type"]`)
      const type = typeInput?.value || "autre"
      const typeLabel = (this.constructor.TYPES_PIECE.find(t => t[0] === type) || [, "Pièce"])[1]
      const gammeInput = this.element.querySelector(`${scope} input[name="piece_gamme"]`)
      const gamme = gammeInput?.value || "milieu"
      const gammeLabel = (this.constructor.GAMMES.find(g => g[0] === gamme) || [, "Milieu de gamme"])[1]
      const travaux = [...this.element.querySelectorAll(`${scope} input[name="piece_travaux"]:checked`)].map(c => c.value)
      const dim = key => parseFloat(this.element.querySelector(`${scope} [data-dim="${key}"]`)?.value || 0)
      return {
        index: i, type, typeLabel, gamme, gammeLabel, travaux,
        mursL: dim("murs_L"), mursH: dim("murs_H"),
        solL: dim("sol_L"), soll: dim("sol_l")
      }
    })
  }

  resolvePrestation(t, reno) {
    if (t.id === "peinture_murs") return reno ? "peinture_murs_reno" : "peinture_murs_neuf"
    if (t.id === "peinture_plafond") return reno ? "peinture_plafond" : "peinture_plafond_neuf"
    return t.id
  }

  // Murs : longueur (développé) × hauteur. Sols / plafonds : longueur × largeur.
  computeSurface(kind, p) {
    const s = kind === "murs" ? p.mursL * p.mursH : p.solL * p.soll
    return Math.round(s * 100) / 100
  }

  surfaceFlags(index) {
    const travaux = [...this.element.querySelectorAll(`[data-piece-index="${index}"] input[name="piece_travaux"]:checked`)].map(c => c.value)
    const kinds = travaux.map(id => this.constructor.TRAVAUX.find(t => t.id === id)?.surface)
    return {
      hasFloor: kinds.some(k => k === "sol" || k === "plafond"),
      hasWalls: kinds.includes("murs")
    }
  }

  // Affiche le bloc "murs" seulement s'il y a des travaux de murs, et le bloc
  // "sol/plafond" seulement s'il y a des travaux au sol ou au plafond.
  configureDimensions(step) {
    const { hasFloor, hasWalls } = this.surfaceFlags(step.dataset.pieceIndex)
    step.querySelector('[data-dim-group="murs"]')?.classList.toggle("hidden", !hasWalls)
    step.querySelector('[data-dim-group="sol"]')?.classList.toggle("hidden", !hasFloor)
  }

  escape(s) { const d = document.createElement("div"); d.textContent = s ?? ""; return d.innerHTML }
}
