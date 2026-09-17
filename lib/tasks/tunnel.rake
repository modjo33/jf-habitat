namespace :tunnel do
  desc "Purge les mesures du tunnel de plus de 6 mois (rétention RGPD)"
  task purger: :environment do
    supprimees = EtapeTunnel.purger
    puts "#{supprimees} mesure(s) de plus de #{EtapeTunnel::RETENTION.inspect} supprimée(s)."
  end

  # Le même tableau que /admin/tunnel, en ligne de commande : pages métier,
  # entonnoir, dernier écran, contacts, et la série jour par jour. Uniquement
  # des compteurs — la table ne porte aucune donnée personnelle.
  desc "Affiche l'entonnoir des N derniers jours (JOURS=7)"
  task entonnoir: :environment do
    jours = (ENV["JOURS"] || 7).to_i
    fin   = Date.current
    debut = fin - (jours - 1).days
    args  = { debut: debut, fin: fin }
    pct   = ->(n, base) { base.to_i.positive? ? " (#{(n * 100.0 / base).round(1)} %)" : "" }

    puts "Tunnel du #{debut.strftime('%d/%m')} au #{fin.strftime('%d/%m/%Y')}"

    pm = EtapeTunnel.pages_metier(**args)
    base_pm = pm[:reels].positive? ? pm[:reels] : pm[:total]
    puts "\nPages métier (marche d'avant l'estimateur)"
    puts format("  %-28s %5d", "Chargements", pm[:total])
    puts format("  %-28s %5d%s", "Visiteurs réels (page_lue)", pm[:reels], pct.(pm[:reels], pm[:total]))
    pm[:par_metier].each { |metier, n| puts format("    %-26s %5d", metier, n) }
    puts format("  %-28s %5d%s", "→ ouvrent l'estimateur", pm[:vers_estimateur], pct.(pm[:vers_estimateur], base_pm))
    puts format("  %-28s %5d%s", "→ appellent", pm[:appels], pct.(pm[:appels], base_pm))
    puts format("  %-28s %5d%s", "→ demandent un rappel", pm[:rappels], pct.(pm[:rappels], base_pm))

    puts "\nEstimateur"
    EtapeTunnel.entonnoir(**args).each do |l|
      passage = l[:passage] ? " (#{l[:passage]} % de passage)" : ""
      puts format("  %-28s %5d%s", l[:libelle], l[:visites], passage)
    end

    de = EtapeTunnel.dernier_ecran(**args)
    puts "\nDernier écran : du bouton à l'envoi"
    puts format("  %-28s %5d", "Arrivés sur Coordonnées", de[:arrives])
    puts format("  %-28s %5d", "Ont tapé le bouton", de[:tentes])
    puts format("  %-28s %5d%s", "Refusés par la validation", de[:bloques], de[:bloques_pct] ? " (#{de[:bloques_pct]} % des taps)" : "")
    puts format("  %-28s %5d", "Devis demandés", de[:soumis])
    EtapeTunnel.motifs_blocage(**args).each { |motif, n| puts format("    %-26s %5d", motif.to_s[0, 26], n) }

    devis_vus = EtapeTunnel.where(etape: "devis_vu", created_at: debut.beginning_of_day..fin.end_of_day)
    puts "\nContacts et signaux hors entonnoir"
    puts format("  %-28s %5d", "Appels (tel: tapé)", EtapeTunnel.appels(**args))
    puts format("  %-28s %5d", "Panneau rappel ouvert", EtapeTunnel.rappels_ouverts(**args))
    puts format("  %-28s %5d", "Rappels demandés", EtapeTunnel.rappels(**args))
    puts format("  %-28s %5d", "Devis vus en clair", devis_vus.count)
    montants = devis_vus.order(:created_at).pluck(:created_at, :source, :appareil, :detail)
    montants.each { |t, s, a, d| puts format("    %s %s/%s %s €", t.strftime("%d/%m %H:%M"), s, a, d) }

    puts "\nPar jour (page_lue · atterrissage · arrivée · réels · contact · devis_vu · appel · rappel · soumis)"
    (debut..fin).each do |jour|
      c = EtapeTunnel.where(created_at: jour.beginning_of_day..jour.end_of_day).group(:etape).count
      puts format("  %s  lue=%-3d att=%-3d arr=%-3d réel=%-3d contact=%-2d devis=%-2d appel=%-2d rappel=%-2d soumis=%d",
                  jour.strftime("%d/%m"), c["page_lue"].to_i, c["atterrissage"].to_i, c["arrivee"].to_i,
                  c[EtapeTunnel::ETAPE_NAVIGATEUR].to_i, c["contact"].to_i, c["devis_vu"].to_i,
                  c["appel"].to_i, c["rappel"].to_i, c["soumis"].to_i)
    end

    if defined?(CampagneAds) && (campagne = CampagneAds.instance)
      puts "\nCampagne Ads (saisie manuelle)"
      puts "  #{campagne.attributes.except('id', 'created_at').map { |k, v| "#{k}=#{v}" }.join(' · ')}"
    end
  end
end
