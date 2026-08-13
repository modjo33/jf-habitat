require "test_helper"

# Les trois générateurs PDF doivent sortir un document valide sans lever —
# un PDF qui explose à la génération, c'est un devis impossible à envoyer
# depuis l'écran d'envoi, découvert devant le client.
class PdfGeneratorsTest < ActiveSupport::TestCase
  test "devis lignes : PDF valide, avec page rétractation et mentions" do
    e = estimation_manuelle
    ligne(e, qte: 7.88, prix: 23, description: "Enduit + ponçage compris")
    ligne(e, libelle: "Protection", unite: "forfait", prix: 90, qte: nil)
    e.update_columns(devis_echeances: Estimation::ECHEANCES_DEFAUT.map(&:dup))
    e.devis_recompute!

    pdf = with_mentions_env do
      DevisLignePdfGenerator.new(e.reload).generate.render
    end

    assert pdf.start_with?("%PDF-"), "le rendu doit être un PDF"
    texte = texte_du_pdf(pdf)
    assert_includes texte, "tractation", "la page droit de rétractation doit être présente"
    assert_includes texte, "cennale",    "la mention d'assurance décennale doit sortir quand la variable est posée"
  end

  test "devis terrain : PDF valide depuis pièces et murs" do
    e = estimation_manuelle
    piece = e.pieces.create!(nom: "Salon")
    piece.murs.create!(libelle: "Mur 1", kind: "mur", longueur: 4, hauteur: 2.5,
                       prix_peinture_m2: 22, type_chantier: "renovation", gamme: "milieu")
    e.devis_recompute!

    pdf = DevisTerrainPdfGenerator.new(e.reload).generate.render
    assert pdf.start_with?("%PDF-")
    assert_operator e.devis_total, :>, 0
  end

  test "facture : PDF valide, mentions réglementaires incluses" do
    client = Client.create!(nom: "Client Facture", statut: "gagne")
    f = Facture.create!(client: client, statut: "emise")
    f.facture_lignes.create!(libelle: "Travaux de peinture", quantite: 10, unite: "m2", prix_unitaire: 22)

    pdf = with_mentions_env { FacturePdfGenerator.new(f.reload).generate.render }
    assert pdf.start_with?("%PDF-")
    assert_includes texte_du_pdf(pdf), "cennale"
  end

  private

  def with_mentions_env
    ENV["LEGAL_ASSURANCE_DECENNALE"] = "Test Assurances, contrat 999"
    ENV["LEGAL_MEDIATEUR"] = "CNPM Médiation"
    yield
  ensure
    ENV.delete("LEGAL_ASSURANCE_DECENNALE")
    ENV.delete("LEGAL_MEDIATEUR")
  end

  # Extraction de texte minimaliste : décompresse les streams puis décode les
  # chaînes hexadécimales de Prawn (<41727469...> → "Arti...") — suffisant pour
  # vérifier qu'un mot-clé ASCII est dans le document.
  def texte_du_pdf(pdf)
    require "zlib"
    flux = pdf.scan(/stream\r?\n(.*?)endstream/m).map { |(s)|
      begin
        Zlib::Inflate.inflate(s)
      rescue Zlib::Error
        s
      end
    }.join
    flux.scan(/<([0-9a-fA-F]+)>/).map { |(h)| [h].pack("H*") }.join(" ")
  end
end
