namespace :tunnel do
  desc "Purge les mesures du tunnel de plus de 6 mois (rétention RGPD)"
  task purger: :environment do
    supprimees = EtapeTunnel.purger
    puts "#{supprimees} mesure(s) de plus de #{EtapeTunnel::RETENTION.inspect} supprimée(s)."
  end

  desc "Affiche l'entonnoir des N derniers jours (JOURS=7)"
  task entonnoir: :environment do
    jours = (ENV["JOURS"] || 7).to_i
    fin   = Date.current
    debut = fin - (jours - 1).days
    puts "Tunnel du #{debut.strftime('%d/%m')} au #{fin.strftime('%d/%m/%Y')}"
    EtapeTunnel.entonnoir(debut: debut, fin: fin).each do |l|
      passage = l[:passage] ? " (#{l[:passage]} % de passage)" : ""
      puts format("  %-28s %5d%s", l[:libelle], l[:visites], passage)
    end
  end
end
