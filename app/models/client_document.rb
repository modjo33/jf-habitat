# Pièce PDF rangée sur une fiche client : contrat, bon de commande, PV de
# réception… Stockée en base comme les justificatifs de dépense, parce que
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

  private

  def pdf_valide
    return if contenu.blank?
    errors.add(:base, "Le fichier doit être un PDF.") unless contenu.byteslice(0, 5) == "%PDF-"
    errors.add(:base, "Le fichier dépasse 10 Mo.") if contenu.bytesize > TAILLE_MAX
  end
end
