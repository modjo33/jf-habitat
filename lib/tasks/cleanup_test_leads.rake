namespace :cleanup do
  desc "Supprime les leads/clients de test (emails @example.com)"
  task test_leads: :environment do
    estimations = Estimation.where("email ILIKE ?", "%@example.com%")
    clients     = Client.where("email ILIKE ?", "%@example.com%")
    e = estimations.count
    c = clients.count
    estimations.destroy_all
    clients.destroy_all
    puts "✓ supprimé #{e} estimation(s) + #{c} client(s) de test"
    puts "CLEANUP_DONE"
  end
end
