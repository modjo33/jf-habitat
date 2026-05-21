namespace :cloudinary do
  desc "Vérifie la config Cloudinary + un upload réel via Active Storage"
  task check: :environment do
    require "stringio"
    require "base64"
    puts "CLD cloud_name=#{Cloudinary.config.cloud_name.inspect} service=#{ActiveStorage::Blob.service.class.name}"
    png = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png), filename: "cloudinary_check.png", content_type: "image/png")
    puts "CLOUDINARY_CHECK_URL=#{blob.url}"
    blob.purge
    puts "CLOUDINARY_CHECK_OK"
  rescue => e
    puts "CLOUDINARY_CHECK_FAIL #{e.class}: #{e.message}"
  end
end
