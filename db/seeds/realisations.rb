# Galerie /realisations. Tant qu'aucune réalisation n'est créée depuis
# /admin/realisations, le helper PhotosHelper#gallery_items retombe sur la
# sélection Unsplash hardcodée. Dès qu'au moins une Realisation existe en DB,
# c'est elle qui pilote la galerie.
#
# Ce seed reste vide volontairement : Johan crée ses propres réalisations
# avec ses vraies photos depuis l'admin.

puts "✓ Galerie réalisations : #{Realisation.count} en base (vide → fallback Unsplash actif)"
