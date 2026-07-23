// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Conversion GA4 — clic-to-call : capte tout clic sur un lien tel: (footer, page contact, CTA).
// Listener délégué posé sur document → survit aux navigations Turbo. gtag n'existe que si
// le visiteur a accepté les cookies (cf. _analytics.html.erb), d'où le guard.
document.addEventListener("click", (event) => {
  const link = event.target.closest('a[href^="tel:"]')
  if (!link) return
  // L'admin charge le même bundle et la fiche estimation affiche le numéro du
  // client : sans ce garde, chaque appel SORTANT de Johan compterait comme un
  // appel entrant.
  if (location.pathname.startsWith("/admin")) return

  // Mesure serveur : gtag ci-dessous ne part QUE si les cookies ont été
  // acceptés, donc il rate la plupart des appels. Celle-ci les voit tous.
  const jeton = document.querySelector('meta[name="csrf-token"]')?.content
  fetch("/suivi-tunnel", {
    method: "POST",
    keepalive: true,
    headers: { "Content-Type": "application/json", "X-CSRF-Token": jeton || "" },
    body: JSON.stringify({ etape: "appel" })
  }).catch(() => {})

  if (typeof window.gtag !== "function") return
  window.gtag("event", "click_to_call", {
    event_category: "engagement",
    phone_number: link.getAttribute("href").replace("tel:", "")
  })
})

// Conversion GA4 — lead (soumission d'estimation). Les données sont posées dans
// #lead-conversion-data par la page de devis ; on envoie l'event ICI (et non via un
// <script> inline, bloqué par la CSP après une navigation Turbo). On retire l'élément
// après envoi pour éviter tout double comptage. gtag peut charger en async, d'où le retry.
function fireLeadConversion(attempt = 0) {
  const el = document.getElementById("lead-conversion-data")
  if (!el) return
  if (typeof window.gtag !== "function") {
    if (attempt < 10) setTimeout(() => fireLeadConversion(attempt + 1), 200)
    return
  }
  window.gtag("event", "generate_lead", {
    currency: "EUR",
    value: parseFloat(el.dataset.value) || 0,
    transaction_id: el.dataset.reference || ""
  })
  // Conversion Google Ads « Demande de devis » (event manuel, sans GTM). Le send_to
  // complet (AW-XXXX/label) est posé côté serveur ; absent → on ne fire pas.
  if (el.dataset.adsSendTo) {
    window.gtag("event", "conversion", {
      send_to: el.dataset.adsSendTo,
      currency: "EUR",
      value: parseFloat(el.dataset.value) || 0,
      transaction_id: el.dataset.reference || ""
    })
  }
  el.remove()
}

document.addEventListener("turbo:load", () => fireLeadConversion())
