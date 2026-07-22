# Garde-fou : les montants de l'analyse de rentabilité (cotisations, marge,
# coût matière, revenu horaire…) ne doivent JAMAIS sortir vers le client.
#
# Cette tâche prend un devis analysé, génère TOUT ce que le client peut recevoir
# — PDF du devis, PDF de la facture, e-mails, écran de présentation — et
# échoue si un seul de ces montants y apparaît.
#
# À relancer après toute modification des générateurs PDF ou des mailers.
namespace :rentabilite do
  desc "Vérifie qu'aucun montant d'analyse ne fuit vers un document client"
  task cloisonnement: :environment do
    require "tmpdir"

    estimation = Estimation.joins(:devis_analyse).first ||
                 Estimation.where("devis_total > 0").first
    abort "Aucun devis exploitable en base." unless estimation

    analyse = estimation.devis_analyse || estimation.create_devis_analyse!
    # Valeurs volontairement distinctives : si elles apparaissent quelque part,
    # ce n'est pas un hasard de mise en page.
    analyse.update!(heures_saisies: 13.37, cout_materiaux_saisi: 424.24, autres_frais: 77.77)
    r = analyse.resultats

    interdits = {
      "coût matériaux"   => r.cout_materiaux,
      "autres frais"     => r.autres_frais,
      "cotisations"      => r.cotisations,
      "bénéfice net"     => r.benefice_net,
      "prix plancher"    => r.prix_plancher,
      "prix conseillé"   => r.prix_conseille,
      "revenu horaire"   => r.revenu_horaire,
      "heures"           => r.heures
    }.compact.transform_values { |v| format("%.2f", v.to_f) }

    mots_interdits = %w[cotisation rentabilit bénéfice benefice marge\ réelle
                        prix\ plancher revenu\ horaire coût\ matière]

    documents = {}

    documents["PDF devis"] = extraire(estimation.devis_pdf_generator.generate.render)
    if (f = Facture.find_by(estimation_id: estimation.id))
      documents["PDF facture"] = extraire(FacturePdfGenerator.new(f).generate.render)
      documents["Mail facture"] = corps_mail(LeadMailer.facture(f, f.message_remerciement))
    end
    documents["Mail devis signé"] = corps_mail(LeadMailer.devis_signe(estimation)) if estimation.devis_signe?

    echecs = []
    documents.each do |nom, contenu|
      texte = contenu.to_s
      interdits.each do |libelle, montant|
        next unless texte.include?(montant)
        echecs << "#{nom} : le montant #{montant} (#{libelle}) apparaît"
      end
      mots_interdits.each do |mot|
        next unless texte.downcase.include?(mot.downcase)
        echecs << "#{nom} : le mot « #{mot} » apparaît"
      end
    end

    puts "Devis testé : #{estimation.reference} (#{documents.size} document(s))"
    puts "Montants surveillés : #{interdits.values.join(', ')}"
    puts

    if echecs.empty?
      puts "✅ Cloisonnement OK — aucun montant ni terme d'analyse dans les documents client."
    else
      echecs.each { |e| puts "❌ #{e}" }
      abort "\nFUITE DÉTECTÉE : #{echecs.size} occurrence(s). Corrige avant de déployer."
    end
  end

  # Extraction du texte via ghostscript : les flux d'un PDF Prawn sont
  # compressés, chercher dans les octets bruts ne trouverait rien et donnerait
  # un faux « tout va bien ».
  def extraire(octets)
    Dir.mktmpdir do |dir|
      src = File.join(dir, "doc.pdf")
      out = File.join(dir, "doc.txt")
      File.binwrite(src, octets)
      ok = system("gs", "-q", "-dNOPAUSE", "-dBATCH", "-sDEVICE=txtwrite",
                  "-sOutputFile=#{out}", src, out: File::NULL, err: File::NULL)
      abort "ghostscript indisponible : impossible de vérifier le cloisonnement." unless ok
      File.read(out, encoding: "UTF-8").scrub
    end
  end

  def corps_mail(mail)
    [mail.subject, mail.html_part&.body&.decoded, mail.text_part&.body&.decoded,
     (mail.body.decoded if mail.parts.empty?)].compact.join("\n")
  end
end
