// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Conversion GA4 — clic-to-call : capte tout clic sur un lien tel: (footer, page contact, CTA).
// Listener délégué posé sur document → survit aux navigations Turbo. gtag n'existe que si
// le visiteur a accepté les cookies (cf. _analytics.html.erb), d'où le guard.
document.addEventListener("click", (event) => {
  const link = event.target.closest('a[href^="tel:"]')
  if (!link || typeof window.gtag !== "function") return
  window.gtag("event", "click_to_call", {
    event_category: "engagement",
    phone_number: link.getAttribute("href").replace("tel:", "")
  })
})
