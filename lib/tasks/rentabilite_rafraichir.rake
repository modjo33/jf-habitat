# Recalcule le verdict de rentabilité (pastille) de tous les devis chiffrés.
#
# Utile après un changement de réglages ou de barème : le verdict stocké
# reflète le dernier calcul, pas les réglages du jour. Ne touche PAS aux taux
# figés de chaque analyse — seulement au résultat affiché.
namespace :rentabilite do
  desc "Recalcule la pastille de rentabilité de tous les devis chiffrés"
  task rafraichir: :environment do
    devis = Estimation.where("devis_total > 0")
    puts "#{devis.count} devis chiffré(s)."
    compte = Hash.new(0)

    devis.find_each do |e|
      analyse = e.devis_analyse || e.create_devis_analyse!
      analyse.rafraichir!
      compte[analyse.reload.niveau] += 1
      montant = format("%.2f", analyse.benefice_net_cache.to_f).tr(".", ",")
      horaire = analyse.revenu_horaire_cache ? "#{format('%.2f', analyse.revenu_horaire_cache.to_f).tr('.', ',')} €/h" : "—"
      puts "  #{analyse.niveau.to_s.ljust(6)} #{e.reference} · #{montant} € net · #{horaire}"
    end

    puts "\nBilan : " + compte.map { |n, c| "#{c} #{n}" }.join(" · ")
  end
end
