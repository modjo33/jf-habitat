require "test_helper"

# Rubrique « Documents » de la fiche client : on range les contrats signés
# avec le client. Le PDF vit en base (Cloudinary rend les PDF vides).
class ClientDocumentsTest < ActionDispatch::IntegrationTest
  AUTH = { "Authorization" => ActionController::HttpAuthentication::Basic
             .encode_credentials("admin", "jfhabitat2026") }.freeze

  setup { @client = Client.create!(nom: "SCI Test", statut: "gagne") }

  def pdf(nom = "Contrat-entretien.pdf", contenu = "%PDF-1.4\ncontrat de test\n%%EOF")
    fichier = Tempfile.new([ "doc", ".pdf" ])
    fichier.binmode
    fichier.write(contenu)
    fichier.rewind
    Rack::Test::UploadedFile.new(fichier.path, "application/pdf", true, original_filename: nom)
  end

  test "un PDF ajouté apparaît sur la fiche et se télécharge à l'identique" do
    assert_difference -> { @client.client_documents.count }, 1 do
      post admin_client_documents_path(@client), headers: AUTH,
           params: { client_document: { titre: "", fichier: pdf } }
    end
    doc = @client.client_documents.last
    assert_equal "Contrat entretien", doc.titre

    get admin_client_path(@client), headers: AUTH
    assert_response :success
    assert_includes response.body, "Contrat entretien"

    get admin_client_document_path(@client, doc), headers: AUTH
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_equal doc.contenu, response.body
  end

  test "un fichier qui n'est pas un PDF est refusé" do
    assert_no_difference -> { ClientDocument.count } do
      post admin_client_documents_path(@client), headers: AUTH,
           params: { client_document: { titre: "Faux", fichier: pdf("photo.pdf", "pas un pdf") } }
    end
    assert_equal "Le fichier doit être un PDF.", flash[:alert]
  end

  test "un document se supprime" do
    doc = @client.client_documents.create!(titre: "À jeter", contenu: "%PDF-1.4 x")
    assert_difference -> { ClientDocument.count }, -1 do
      delete admin_client_document_path(@client, doc), headers: AUTH
    end
  end
end
