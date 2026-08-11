import { Controller } from "@hotwired/stimulus"

// Parcours d'estimation façon Typeform : une question par écran.
//
// Parcours (6 écrans pour une pièce, 8 pour trois) :
//   1. type de chantier
//   2. quelles pièces  → compteur par type (remplace « combien ? » + un écran de type par pièce)
//   3. travaux + gamme → posés UNE FOIS pour tout le chantier
//   4. dimensions      → un écran par pièce (seul écran réellement par pièce)
//   5. précisions      → état, peinture, teintes, sol, étage : un seul écran
//   6. coordonnées     → récapitulatif + options + devis flouté + formulaire
//
// À la soumission, on assemble les estimation_lines_attributes (1 par pièce ×
// prestation, surface calculée, options auto) et on poste sur l'action create.
export default class extends Controller {
  static targets = ["step", "progressBar", "progressText", "back", "piecesContainer", "pieceTemplate", "recap", "lines", "error", "loader", "devisTeaser", "devisRows", "submitBtn", "fourchette", "fourchetteMontants"]

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

  // Périmètre d'une pièce déduit de sa surface au sol. Pour un rectangle de
  // proportions courantes (4:3), périmètre ≈ 4,05 × √surface — 17,2 m pour
  // 18 m². Approximation assumée : le client connaît ses m², jamais le
  // développé de ses murs, et Johan affine au métré sur place.
  static COEF_PERIMETRE = 4.05

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
    if (step.dataset.validate === "dimensions") this.configureDimensions(step)
    if (step.dataset.precisions !== undefined) this.configurePrecisions(step)
    if (step.dataset.step === "contact") this.revealDevis()
    this.updateProgress()
    this.clearError()
    this.suivre(step)
    if (this.hasBackTarget) this.backTarget.classList.toggle("invisible", this.index === 0)
    const focusable = step.querySelector("input:not([type=hidden]), select, textarea, button[data-autofocus]")
    if (focusable) setTimeout(() => focusable.focus(), 60)
  }

  // ---- Mesure du tunnel ----------------------------------------------------

  // Les écrans n'existent que côté client : sans cette balise, le serveur ne
  // voit que l'arrivée et la soumission, jamais l'écran où le visiteur décroche.
  // Indépendant de GA4, qui est muet tant que les cookies ne sont pas acceptés.
  suivre(step) {
    // Les écrans « dimensions » sont générés une fois par pièce et ne portent
    // pas de data-step ; côté serveur ils sont dédoublonnés de toute façon.
    const etape = step.dataset.step || (step.dataset.validate === "dimensions" ? "dimensions" : null)
    if (!etape) return
    this.baliser(etape)
  }

  // Envoi d'un événement de mesure. Silencieux par construction : la mesure ne
  // doit jamais gêner le parcours.
  baliser(etape) {
    const jeton = document.querySelector('meta[name="csrf-token"]')?.content
    fetch("/suivi-tunnel", {
      method: "POST",
      keepalive: true,
      headers: { "Content-Type": "application/json", "X-CSRF-Token": jeton || "" },
      body: JSON.stringify({ etape })
    }).catch(() => {})
  }

  next() {
    const step = this.steps[this.index]
    if (!this.validateStep(step)) return
    // Les écrans « dimensions » dépendent des pièces ET des travaux : on les
    // (re)génère une fois les deux connus.
    if (step.dataset.step === "travaux_gamme") this.generatePieces()
    this.go(1)
  }

  prev() { this.go(-1) }

  go(dir) { this.show(this.index + dir) }

  // ---- Écran « quelles pièces » -------------------------------------------

  incPiece(event) { this.bumpPiece(event, +1) }
  decPiece(event) { this.bumpPiece(event, -1) }

  bumpPiece(event, delta) {
    const row = event.currentTarget.closest("[data-piece-row]")
    const badge = row.querySelector("[data-piece-count]")
    const next = Math.max(0, Math.min(parseInt(badge.textContent, 10) + delta, 12))
    badge.textContent = next
    row.classList.toggle("border-accent", next > 0)
    row.classList.toggle("bg-accent/5", next > 0)
    this.clearError()
    this.updateProgress()
  }

  // [{ type, label }] dans l'ordre d'affichage, une entrée par pièce demandée.
  selectedPieces() {
    const out = []
    this.element.querySelectorAll("[data-piece-row]").forEach(row => {
      const n = parseInt(row.querySelector("[data-piece-count]").textContent, 10) || 0
      for (let k = 0; k < n; k++) {
        out.push({ type: row.dataset.pieceType, label: row.dataset.pieceLabel })
      }
    })
    return out
  }

  // Deux pièces du même type doivent être distinguables au récapitulatif.
  labelForPiece(pieces, i) {
    const p = pieces[i]
    const sameType = pieces.filter(x => x.type === p.type)
    if (sameType.length < 2) return p.label
    const rank = pieces.slice(0, i + 1).filter(x => x.type === p.type).length
    return `${p.label} ${rank}`
  }

  onTravauxChange() { this.clearError() }

  // ---- Écran « taille de la pièce » ---------------------------------------

  choisirTaille(event) {
    const btn = event.currentTarget
    const step = btn.closest(".wizard-step")
    step.querySelectorAll("[data-taille]").forEach(b => b.dataset.selected = "false")
    btn.dataset.selected = "true"
    const champ = step.querySelector('[data-dim="surface_sol"]')
    if (champ) { champ.value = btn.dataset.valeur; this.majSurface(step) }
    this.clearError()
  }

  basculerPrecis(event) { this.basculerMode(event.currentTarget.closest(".wizard-step"), "precis") }
  basculerSimple(event) { this.basculerMode(event.currentTarget.closest(".wizard-step"), "simple") }

  basculerMode(step, mode) {
    step.dataset.saisie = mode
    step.querySelector('[data-mode="simple"]')?.classList.toggle("hidden", mode !== "simple")
    step.querySelector('[data-mode="precis"]')?.classList.toggle("hidden", mode === "simple")
    this.configureDimensions(step)
    this.clearError()
  }

  liveSurface(event) { this.majSurface(event.target.closest(".wizard-step")) }

  // Affiche le résultat du calcul pendant la frappe. Sans ça, la promesse
  // « la surface est calculée automatiquement » n'était tenue nulle part.
  majSurface(step) {
    const sortie = step.querySelector("[data-surface-live]")
    if (!sortie) return
    const p = this.lireDimensions(step)
    const { hasFloor, hasWalls } = this.surfaceFlags()
    const morceaux = []
    if (hasWalls && p.mursSurface > 0) morceaux.push(`≈ ${this.fmt(p.mursSurface)} m² de murs`)
    if (hasFloor && p.solSurface > 0) morceaux.push(`${this.fmt(p.solSurface)} m² au sol`)
    sortie.textContent = morceaux.length ? `→ ${morceaux.join(" · ")} à traiter` : ""
  }

  fmt(v) { return Number(v).toLocaleString("fr-FR", { maximumFractionDigits: 1 }) }

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

  // Total anticipé : tant que les écrans « dimensions » ne sont pas générés, on
  // les projette depuis les compteurs. Sans ça le dénominateur bondirait après
  // l'écran travaux et la barre RECULERAIT — abandon assuré.
  get projectedTotal() {
    const current = this.steps.length
    const generated = this.element.querySelectorAll("[data-piece-index]").length
    if (generated > 0) return current
    return current + Math.max(1, this.selectedPieces().length)
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
    } else if (kind === "pieces") {
      if (this.selectedPieces().length === 0) return this.fail(step, "Ajoutez au moins une pièce.")
    } else if (kind === "travaux_gamme") {
      const any = step.querySelectorAll('input[name="piece_travaux"]:checked').length > 0
      if (!any) return this.fail(step, "Sélectionnez au moins un type de travaux.")
      const gamme = step.querySelector('input[name="piece_gamme"]')
      if (!gamme || !gamme.value) return this.fail(step, "Choisissez un niveau de finition.")
    } else if (kind === "dimensions") {
      // Les bornes min/max des champs sont désormais contrôlées ICI : le
      // formulaire est en `novalidate` (voir new.html.erb), donc plus personne
      // ne rattrape une hauteur à 25 m. Une valeur aberrante partait sinon au
      // serveur et gonflait le chiffrage d'un facteur dix.
      const horsBornes = this.champHorsBornes(step)
      if (horsBornes) return this.fail(step, horsBornes.message, horsBornes.champ)
      const p = this.lireDimensions(step)
      const { hasFloor, hasWalls } = this.surfaceFlags()
      if (hasWalls && !(p.mursSurface > 0)) return this.fail(step, "Indiquez la taille de la pièce.")
      if (hasFloor && !(p.solSurface > 0)) return this.fail(step, "Indiquez la taille de la pièce.")
    } else if (kind === "contact") {
      const champNom = step.querySelector('[name="estimation[nom]"]')
      const nom = champNom?.value.trim()
      const champEmail = step.querySelector('[name="estimation[email]"]')
      const champTel = step.querySelector('[name="estimation[telephone]"]')
      const email = champEmail?.value.trim()
      const tel = champTel?.value.trim()
      if (!nom) return this.fail(step, "Merci d'indiquer votre nom.", champNom)
      if (!email) return this.fail(step, "Merci d'indiquer votre e-mail.", champEmail)
      if (!tel) return this.fail(step, "Merci d'indiquer votre téléphone.", champTel)

      // On nettoie le champ AVANT l'envoi plutôt que de refuser : un Français
      // écrit son numéro « 06 12 34 56 78 » ou « 06.12.34.56.78 », et le
      // serveur n'accepte que les dix chiffres collés. Le rejet arrivait après
      // six écrans remplis, effaçait tout le parcours, et personne ne
      // recommençait.
      if (champTel) champTel.value = tel.replace(/[\s.\-() ]/g, "")
      if (champEmail) champEmail.value = email
      if (champTel && !/^(\+33|0)[1-9](\d{2}){4}$/.test(champTel.value)) {
        return this.fail(step, "Le téléphone doit être un numéro français à 10 chiffres.", champTel)
      }
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
        return this.fail(step, "L'adresse e-mail ne semble pas valide.", champEmail)
      }
      // Le code postal dit si le chantier est dans la zone d'intervention, et
      // porte le coefficient régional du chiffrage. Sans lui, un lead payé peut
      // se révéler être à 250 km — c'est arrivé. Contrôlé ICI et pas seulement
      // côté serveur : un refus serveur re-rend le formulaire et efface tout le
      // parcours du visiteur, qui ne recommence jamais.
      const champCp = step.querySelector('[name="estimation[code_postal]"]')
      const cp = champCp?.value.trim()
      if (!cp) return this.fail(step, "Le code postal du chantier est requis.", champCp)
      // Même logique que le téléphone : « 33 000 » est nettoyé, pas refusé.
      if (champCp) champCp.value = cp.replace(/\s/g, "")
      if (!/^\d{5}$/.test(champCp.value)) return this.fail(step, "Le code postal doit comporter 5 chiffres.", champCp)
    }
    return true
  }

  // ⚠️ Afficher le message ne suffit pas : il faut l'AMENER SOUS LES YEUX.
  // Le bouton est `sticky`, donc tapable depuis n'importe quel endroit de
  // l'écran, alors que le message vit dans le flux juste au-dessus de sa
  // position naturelle. Mesuré en prod sur iPhone : au refus, le message
  // s'affichait 1 150 à 1 350 px SOUS le bas de la fenêtre — invisible. Le
  // visiteur tapait, rien ne bougeait, il recommençait, puis il partait. C'est
  // la première cause des parcours remplis jusqu'au bout sans aucun envoi.
  fail(step, msg, champ = null) {
    this.clearError()
    const box = step.querySelector("[data-wizard-target='error']") || (this.hasErrorTarget && this.errorTarget)
    if (box) {
      box.textContent = msg
      box.classList.remove("hidden")
      box.scrollIntoView({ block: "center", behavior: "smooth" })
    }
    // Le champ fautif reçoit le focus : le clavier s'ouvre au bon endroit et le
    // visiteur sait quoi corriger, sans avoir à relire tout le formulaire.
    if (champ) setTimeout(() => { try { champ.focus() } catch (e) {} }, 200)
    return false
  }

  // Première mesure de dimension hors de ses bornes, ou null.
  // Libellés lisibles : le visiteur doit savoir QUELLE case corriger.
  champHorsBornes(step) {
    const libelles = {
      hauteur: "la hauteur sous plafond", murs_L: "la longueur des murs",
      murs_H: "la hauteur des murs", sol_L: "la longueur du sol",
      sol_l: "la largeur du sol", surface_sol: "la surface au sol"
    }
    for (const champ of step.querySelectorAll("input[data-dim]")) {
      const v = parseFloat(String(champ.value).replace(",", "."))
      if (!Number.isFinite(v) || champ.value === "") continue
      const min = parseFloat(champ.min), max = parseFloat(champ.max)
      const tropBas = Number.isFinite(min) && v < min
      const tropHaut = Number.isFinite(max) && v > max
      if (tropBas || tropHaut) {
        const libelle = libelles[champ.dataset.dim] || "cette dimension"
        const borne = tropHaut ? `dépasser ${this.fmt(max)}` : `être inférieure à ${this.fmt(min)}`
        return { champ, message: `Vérifiez ${libelle} : elle ne peut pas ${borne}.` }
      }
    }
    return null
  }

  clearError() {
    this.element.querySelectorAll("[data-wizard-target='error']").forEach(e => { e.textContent = ""; e.classList.add("hidden") })
  }

  // ---- Génération des écrans « dimensions » -------------------------------

  generatePieces() {
    const pieces = this.selectedPieces()
    this.piecesContainerTarget.innerHTML = ""
    pieces.forEach((p, i) => {
      const html = this.pieceTemplateTarget.innerHTML
        .replace(/__N__/g, i + 1)
        .replace(/__TYPE__/g, p.type)
        .replace(/__LABEL__/g, this.escape(this.labelForPiece(pieces, i)))
      this.piecesContainerTarget.insertAdjacentHTML("beforeend", html)
    })
  }

  // ---- Précisions : ne montrer que les blocs pertinents -------------------

  configurePrecisions(step) {
    const reno = this.chantier() === "renovation"
    step.querySelector('[data-prec-block="reno"]')?.classList.toggle("hidden", !reno)
    step.querySelector('[data-prec-block="peinture"]')?.classList.toggle("hidden", !this.projectHas("peinture"))
    step.querySelector('[data-prec-block="parquet"]')?.classList.toggle("hidden", !this.projectHas("parquet"))
  }

  projectHas(prefix) {
    return this.selectedTravaux().some(v => v.startsWith(prefix))
  }

  selectedTravaux() {
    return [...this.element.querySelectorAll('input[name="piece_travaux"]:checked')].map(c => c.value)
  }

  // ---- Récapitulatif (sans prix) ------------------------------------------

  // Rendu sur l'écran des coordonnées. Les options « auto » sont des cases
  // pré-cochées selon le type de chantier mais modifiables : ce sont elles la
  // source de vérité pour buildLines.
  buildRecap() {
    if (!this.hasRecapTarget) return
    const reno = this.chantier() === "renovation"
    const pieces = this.collectPieces()
    const travauxLabels = this.selectedTravaux()
      .map(t => this.constructor.TRAVAUX.find(x => x.id === t)?.label).filter(Boolean)
    const gamme = this.gammeLabel()

    let rows = ""
    pieces.forEach(p => {
      const dimParts = []
      if (p.mursL > 0 && p.mursH > 0) dimParts.push(`murs ${p.mursL}×${p.mursH} m`)
      if (p.solL > 0 && p.soll > 0) dimParts.push(`sol ${p.solL}×${p.soll} m`)
      rows += `
        <div class="flex items-baseline justify-between gap-3 py-1.5 border-b border-border-warm/50 last:border-0">
          <span class="text-sm font-semibold text-ink">${this.escape(p.typeLabel)}</span>
          <span class="text-xs text-ink-light">${this.escape(dimParts.join(" · "))}</span>
        </div>`
    })

    // Une seule série d'options pour le chantier (travaux et gamme sont communs).
    let opts = ""
    if (this.projectHas("peinture")) opts += this.optionCheckbox("poncage_peinture", "Ponçage / préparation des supports", reno)
    if (this.projectHas("parquet")) {
      opts += this.optionCheckbox("depose_evacuation", "Dépose & évacuation de l'ancien revêtement", reno)
      opts += this.optionCheckbox("poncage", "Ponçage + vitrification du parquet", false)
    }

    this.recapTarget.innerHTML = `
      <div class="p-5 bg-sand rounded-xl border border-border-warm/60">
        <div class="text-[11px] font-bold uppercase tracking-[0.15em] text-ink-light mb-2">Votre projet</div>
        ${rows}
        <div class="text-sm text-ink-soft mt-3">${travauxLabels.map(l => this.escape(l)).join(" · ")}</div>
        <div class="text-xs font-semibold text-accent uppercase tracking-wide mt-1">Gamme : ${this.escape(gamme)}</div>
        ${opts ? `<div class="mt-3 pt-3 border-t border-border-warm/60 space-y-2">${opts}</div>` : ""}
      </div>`
    this.recapTarget.classList.remove("hidden")
  }

  optionCheckbox(key, label, checked) {
    return `
      <label class="flex items-center gap-2.5 cursor-pointer text-sm text-ink-soft">
        <input type="checkbox" data-opt-key="${key}" ${checked ? "checked" : ""}
               class="w-4 h-4 rounded border-border-warm text-accent focus:ring-accent/40">
        ${this.escape(label)}
      </label>`
  }

  optionEnabled(key) {
    const cb = this.element.querySelector(`[data-opt-key="${key}"]`)
    return cb ? cb.checked : false
  }

  // ---- Devis flouté + loader ----------------------------------------------

  // À l'arrivée sur l'écran coordonnées : on « calcule » (loader) puis on
  // dévoile le récapitulatif et un devis dont les montants restent floutés. Le
  // devis chiffré réel n'est rendu qu'après soumission (page show).
  revealDevis() {
    if (!this.hasLoaderTarget || !this.hasDevisTeaserTarget) return
    this.buildRecap()
    this.buildDevisTeaser()
    this.loaderTarget.classList.remove("hidden")
    this.devisTeaserTarget.classList.add("hidden")
    if (this.hasRecapTarget) this.recapTarget.classList.add("hidden")
    if (this.hasFourchetteTarget) this.fourchetteTarget.classList.add("hidden")
    this.chargerFourchette()
    clearTimeout(this._loaderTimer)
    this._loaderTimer = setTimeout(() => {
      this.loaderTarget.classList.add("hidden")
      this.devisTeaserTarget.classList.remove("hidden")
      if (this.hasRecapTarget) this.recapTarget.classList.remove("hidden")
      if (this.hasFourchetteTarget && this._fourchette) this.afficherFourchette()
    }, 1500)
  }

  // Ordre de grandeur calculé PAR LE SERVEUR : le barème ne descend jamais
  // dans le navigateur, et la réponse ne contient qu'un intervalle arrondi,
  // jamais le total exact (cf. EstimationsController#gated_preview).
  async chargerFourchette() {
    this._fourchette = null
    const lines = this.collectPieces().flatMap(p =>
      this.selectedTravaux().map(id => {
        const t = this.constructor.TRAVAUX.find(x => x.id === id)
        if (!t) return null
        const surface = this.computeSurface(t.surface, p)
        if (!(surface > 0)) return null
        return { prestation: this.resolvePrestation(t, this.chantier() === "renovation"),
                 gamme: p.gamme, type_piece: p.type, mode_saisie: "surface", surface }
      }).filter(Boolean))
    if (!lines.length) return

    // `lines[][clé]` et non `lines[0][clé]` : le service reçoit un Array, une
    // clé indexée lui arriverait sous forme de paires et serait ignorée.
    const params = new URLSearchParams()
    lines.forEach(l => Object.entries(l).forEach(([k, v]) => params.append(`lines[][${k}]`, v)))
    const etage = this.element.querySelector('[name="estimation[etage]"]')?.value
    const cp = this.element.querySelector('[name="estimation[code_postal]"]')?.value
    if (etage) params.append("etage", etage)
    if (cp) params.append("code_postal", cp)

    try {
      const jeton = document.querySelector('meta[name="csrf-token"]')?.content
      const r = await fetch("/estimation/preview.json", {
        method: "POST",
        headers: { Accept: "application/json", "Content-Type": "application/x-www-form-urlencoded",
                   ...(jeton ? { "X-CSRF-Token": jeton } : {}) },
        body: params
      })
      if (!r.ok) return
      const data = await r.json()
      this._fourchette = data.fourchette
      // Le loader peut déjà être terminé si la réponse a tardé.
      if (this.hasLoaderTarget && this.loaderTarget.classList.contains("hidden")) this.afficherFourchette()
    } catch (_) { /* pas de fourchette : le tunnel continue normalement */ }
  }

  afficherFourchette() {
    if (!this._fourchette || !this.hasFourchetteMontantsTarget) return
    const eur = v => Number(v).toLocaleString("fr-FR", { maximumFractionDigits: 0 }) + " €"
    this.fourchetteMontantsTarget.textContent = `${eur(this._fourchette.min)} et ${eur(this._fourchette.max)}`
    this.fourchetteTarget.classList.remove("hidden")
  }

  buildDevisTeaser() {
    const pieces = this.collectPieces()
    const labels = this.selectedTravaux()
      .map(t => this.constructor.TRAVAUX.find(x => x.id === t)?.label).filter(Boolean).join(", ")
    let rows = ""
    pieces.forEach(p => {
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

  // ---- Assemblage + soumission --------------------------------------------

  submitForm(event) {
    if (event) event.preventDefault()
    const step = this.steps[this.index]
    // On distingue « personne ne tape le bouton » de « le bouton est tapé mais
    // rien ne part ». Sans cette balise, un refus silencieux ressemble
    // exactement à un visiteur qui renonce — c'est ce qui a coûté des semaines.
    this.baliser("envoi_tente")
    if (!this.validateStep(step)) {
      this.baliser("envoi_bloque")
      return
    }
    this.buildPrecisions()
    this.buildLines()
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = true
      this.submitBtnTarget.classList.add("opacity-70", "pointer-events-none")
      this.submitBtnTarget.innerHTML = '<span class="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin"></span> Génération du devis…'
    }
    this.element.requestSubmit()
  }

  // Compile les réponses « précisions » dans le champ message (visible côté
  // admin et dans l'email de lead) — pas de colonne dédiée nécessaire.
  buildPrecisions() {
    const val = name => this.element.querySelector(`[name="${name}"]`)?.value?.trim()
    const rows = [
      ["État des surfaces", val("prec_etat")],
      ["Type de peinture", val("prec_peinture")],
      ["Teintes", val("prec_teintes")],
      ["Revêtement de sol actuel", val("prec_sol")],
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
    const travaux = this.selectedTravaux()
    this.linesTarget.innerHTML = ""
    let n = 0
    pieces.forEach(p => {
      travaux.forEach(travailId => {
        const t = this.constructor.TRAVAUX.find(x => x.id === travailId)
        if (!t) return
        const surface = this.computeSurface(t.surface, p)
        if (!(surface > 0)) return // travail sans dimension saisie pour cette pièce
        const prestation = this.resolvePrestation(t, reno)
        const isPeinture = prestation.startsWith("peinture")
        const isParquet = prestation.startsWith("parquet")
        this.addLine(n, {
          piece: p.typeLabel,
          type_piece: p.type,
          prestation: prestation,
          gamme: p.gamme,
          mode_saisie: "surface",
          surface: surface.toFixed(2),
          poncage: (isParquet && this.optionEnabled("poncage")) ? "1" : "0",
          poncage_peinture: (isPeinture && this.optionEnabled("poncage_peinture")) ? "1" : "0",
          depose_evacuation: (isParquet && this.optionEnabled("depose_evacuation")) ? "1" : "0"
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

  gamme() {
    return this.element.querySelector('input[name="piece_gamme"]')?.value || "milieu"
  }

  gammeLabel() {
    const g = this.gamme()
    return (this.constructor.GAMMES.find(x => x[0] === g) || [, "Milieu de gamme"])[1]
  }

  // Une pièce = un écran « dimensions » généré. Travaux et gamme sont communs
  // au chantier, le type vient de l'écran « quelles pièces ».
  collectPieces() {
    const gamme = this.gamme()
    const gammeLabel = this.gammeLabel()
    return [...this.element.querySelectorAll("[data-piece-index]")].map(step => ({
      index: step.dataset.pieceIndex,
      type: step.dataset.pieceType || "autre",
      typeLabel: step.dataset.pieceLabel || "Pièce",
      gamme, gammeLabel,
      ...this.lireDimensions(step)
    }))
  }

  // Surfaces d'une pièce, quel que soit le mode de saisie.
  // Simple : la surface au sol est donnée, le développé des murs s'en déduit.
  // Précis : les mesures du client priment, aucune approximation.
  lireDimensions(step) {
    const dim = key => parseFloat(String(step.querySelector(`[data-dim="${key}"]`)?.value ?? "").replace(",", ".")) || 0
    const arrondi = v => Math.round(v * 100) / 100

    if (step.dataset.saisie === "precis") {
      return {
        mode: "precis",
        mursSurface: arrondi(dim("murs_L") * dim("murs_H")),
        solSurface:  arrondi(dim("sol_L") * dim("sol_l"))
      }
    }
    const surface = dim("surface_sol")
    const hauteur = dim("hauteur") || 2.5
    const perimetre = surface > 0 ? this.constructor.COEF_PERIMETRE * Math.sqrt(surface) : 0
    return {
      mode: "simple",
      surfaceSol: surface, hauteur,
      mursSurface: arrondi(perimetre * hauteur),
      solSurface:  arrondi(surface)
    }
  }

  resolvePrestation(t, reno) {
    if (t.id === "peinture_murs") return reno ? "peinture_murs_reno" : "peinture_murs_neuf"
    if (t.id === "peinture_plafond") return reno ? "peinture_plafond" : "peinture_plafond_neuf"
    return t.id
  }

  computeSurface(kind, p) {
    return kind === "murs" ? (p.mursSurface || 0) : (p.solSurface || 0)
  }

  surfaceFlags() {
    const kinds = this.selectedTravaux()
      .map(id => this.constructor.TRAVAUX.find(t => t.id === id)?.surface)
    return {
      hasFloor: kinds.some(k => k === "sol" || k === "plafond"),
      hasWalls: kinds.includes("murs")
    }
  }

  // N'affiche que ce qui sert : pas de hauteur sous plafond quand il n'y a que
  // du sol à poser, pas de bloc « murs » quand aucun mur n'est concerné.
  configureDimensions(step) {
    const { hasFloor, hasWalls } = this.surfaceFlags()
    step.dataset.saisie ||= "simple"
    step.querySelector('[data-champ="hauteur"]')?.classList.toggle("hidden", !hasWalls)
    step.querySelector('[data-dim-group="murs"]')?.classList.toggle("hidden", !hasWalls)
    step.querySelector('[data-dim-group="sol"]')?.classList.toggle("hidden", !hasFloor)
    this.majSurface(step)
  }

  escape(s) { const d = document.createElement("div"); d.textContent = s ?? ""; return d.innerHTML }
}
