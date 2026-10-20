# Pièce rangée sur une fiche client : contrat, bon de commande, PV de
# réception (PDF), ou image (planche d'ambiance, photo) à joindre à un mail.
# Stockée en base comme les justificatifs de dépense, parce que
# Cloudinary stocke les PDF mais renvoie un fichier vide au téléchargement.
class ClientDocument < ApplicationRecord
  TAILLE_MAX = 10.megabytes

  belongs_to :client

  validates :titre, presence: true, length: { maximum: 150 }
  validates :contenu, presence: true
  validate :pdf_valide

  scope :recents_dabord, -> { order(created_at: :desc) }

  # Construit le document depuis un fichier envoyé par formulaire. Le titre
  # retombe sur le nom du fichier sans extension s'il n'est pas saisi.
  def fichier=(upload)
    return if upload.blank?
    self.contenu = upload.read
    self.nom_fichier = upload.original_filename
    self.taille = contenu.bytesize
    self.titre = File.basename(nom_fichier.to_s, ".*").tr("-_", "  ").squish if titre.blank?
  end

  # Type déduit des premiers octets : on ne fait pas confiance à l'extension.
  def mime_type
    debut = contenu.to_s.byteslice(0, 8).to_s.b
    if debut.start_with?("%PDF-") then "application/pdf"
    elsif debut.start_with?("\x89PNG".b) then "image/png"
    elsif debut.start_with?("\xFF\xD8\xFF".b) then "image/jpeg"
    end
  end

  def image? = mime_type.to_s.start_with?("image/")

  # Nom de fichier propre pour une pièce jointe.
  def nom_piece_jointe
    nom_fichier.presence || "#{titre.parameterize}#{image? ? (mime_type == 'image/png' ? '.png' : '.jpg') : '.pdf'}"
  end

  private

  def pdf_valide
    return if contenu.blank?
    errors.add(:base, "Le fichier doit être un PDF ou une image (PNG, JPEG).") unless mime_type
    errors.add(:base, "Le fichier dépasse 10 Mo.") if contenu.bytesize > TAILLE_MAX
  end
end
