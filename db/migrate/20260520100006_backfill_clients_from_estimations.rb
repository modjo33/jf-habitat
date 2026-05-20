class BackfillClientsFromEstimations < ActiveRecord::Migration[8.1]
  # Pour chaque Estimation existante sans client_id, on trouve ou crée un Client
  # par email (case-insensitive). Met à jour les champs vides du client en
  # priorité (téléphone, adresse, ville) — sans écraser ce qui est déjà saisi.

  def up
    Estimation.where(client_id: nil).find_each do |est|
      next if est.email.blank?

      client = Client.find_or_initialize_by(email: est.email.to_s.downcase.strip)
      client.nom         = est.nom         if client.nom.blank?
      client.telephone ||= est.telephone
      client.adresse   ||= est.adresse
      client.code_postal ||= est.code_postal
      client.ville       ||= est.ville
      client.statut    ||= "nouveau"
      client.derniere_interaction_at ||= est.created_at
      next unless client.save

      est.update_columns(client_id: client.id)
    rescue => e
      Rails.logger.warn "[BackfillClients] estimation##{est.id} : #{e.class} · #{e.message}"
    end
  end

  def down
    # Pas de rollback automatique — la suppression des clients couperait les liens.
    raise ActiveRecord::IrreversibleMigration
  end
end
