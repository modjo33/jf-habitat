require "test_helper"

class LeadMailerTest < ActionMailer::TestCase
  setup do
    @estimation = Estimation.create!(nom: "Client Test", email: "client@example.com", origine: "manuel",
                                     statut: "contacte", type_chantier: "renovation", ville: "Bordeaux")
    @estimation.devis_lignes.create!(section: "Séjour", libelle: "Peinture", unite: "m2", quantite: 10, prix_unitaire: 20)
    @estimation.devis_recompute!
    @estimation.reload
    @estimation.create_devis_document!(data: "%PDF-1.4 test")
  end

  test "le message saisi dans l'admin garde ses paragraphes et ses retours à la ligne" do
    message = "Bonjour Client,\n\nComme convenu, voici le devis.\nIl est détaillé pièce par pièce.\n\nBien cordialement,\nJohan"
    mail = LeadMailer.devis_document(@estimation, message)
    html = mail.html_part.body.decoded

    assert_equal 3, html.scan("<p style=\"margin:0 0 14px 0;\">").size, "un <p> par paragraphe"
    assert_includes html, "voici le devis.\n<br />Il est détaillé", "retour simple → <br>"
    refute_includes html, "pre-wrap", "jamais de white-space:pre-wrap : les clients mail l'ignorent"
    assert_includes html, @estimation.reference
    assert_includes html, "200,00 €"
    assert_includes mail.text_part.body.decoded, "Comme convenu, voici le devis."
  end

  test "le HTML du message est neutralisé, le logo est joint en inline et le PDF en pièce jointe" do
    mail = LeadMailer.devis_document(@estimation, "Bonjour <script>alert(1)</script>")
    html = mail.html_part.body.decoded

    refute_includes html, "<script>"
    logo = mail.attachments.find { |a| a.filename == "logo.png" }
    assert logo&.inline?, "logo attendu en inline (cid)"
    assert_includes html, "cid:", "l'en-tête référence le logo par cid"
    assert mail.attachments.any? { |a| a.filename == "devis-jf-habitat-#{@estimation.reference}.pdf" }
  end

  test "sans message, le texte par défaut est envoyé dans la même enveloppe" do
    html = LeadMailer.devis_document(@estimation, nil).html_part.body.decoded
    assert_includes html, "Bonjour Client Test,"
    assert_includes html, "devis-jf-habitat-#{@estimation.reference}.pdf"
  end
end
