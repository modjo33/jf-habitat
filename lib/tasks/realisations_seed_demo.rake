namespace :realisations do
  desc "Crée des réalisations éditables à partir des photos de démo (si la table est vide)"
  task seed_demo: :environment do
    if Realisation.exists?
      puts "Réalisations déjà présentes (#{Realisation.count}) — rien à faire."
      next
    end

    require "open-uri"
    base = PhotosHelper::UNSPLASH_BASE

    PhotosHelper::GALLERY_FALLBACK_LEGENDES.each_with_index do |item, i|
      photo_id = PhotosHelper::GALLERY_FALLBACK_PHOTOS[item[:key]]
      url = "#{base}/#{photo_id}?w=1200&q=80&fit=crop&fm=jpg"
      r = Realisation.new(metier: item[:metier], legende: item[:legende], position: (i + 1) * 10, active: true)
      begin
        io = URI.parse(url).open("rb")
        r.photo.attach(io: io, filename: "#{item[:key]}.jpg", content_type: "image/jpeg")
        r.save!
        puts "✓ #{item[:legende]}"
      rescue => e
        puts "⚠️ #{item[:key]} : #{e.class} #{e.message}"
      end
    end
    puts "REALISATIONS_SEED_DONE (#{Realisation.count} en base)"
  end
end
