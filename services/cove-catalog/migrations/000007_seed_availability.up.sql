-- Seed catalog.availability — one listing per item at its producer's place.
-- Place UUIDs are hardcoded (seeded by cove-directory 000004_seed_places).

INSERT INTO catalog.availability (item_id, place_id, listing_source, listing_url, is_active)
VALUES (
    'f3000001-1234-0000-0000-000000000001',
    'f2000001-cafe-0000-0000-000000000001',
    'producer_listed',
    'https://ritualcoffee.com/coffee/colombia-familia-montano',
    true
)
ON CONFLICT (item_id, place_id) DO NOTHING;

INSERT INTO catalog.availability (item_id, place_id, listing_source, listing_url, is_active)
VALUES (
    'f3000001-1234-0000-0000-000000000002',
    'f2000001-cafe-0000-0000-000000000002',
    'producer_listed',
    'https://onyxcoffeelab.com/products/southern-weather-blend',
    true
)
ON CONFLICT (item_id, place_id) DO NOTHING;

INSERT INTO catalog.availability (item_id, place_id, listing_source, listing_url, is_active)
VALUES (
    'f3000001-1234-0000-0000-000000000003',
    'f2000001-cafe-0000-0000-000000000003',
    'producer_listed',
    'https://www.urbanoutfitters.com/shop/iets-franz-balloon-cargo-pant',
    true
)
ON CONFLICT (item_id, place_id) DO NOTHING;

INSERT INTO catalog.availability (item_id, place_id, listing_source, listing_url, is_active)
VALUES (
    'f3000001-1234-0000-0000-000000000004',
    'f2000001-cafe-0000-0000-000000000004',
    'producer_listed',
    'https://homeshake.bandcamp.com/album/under-the-weather',
    true
)
ON CONFLICT (item_id, place_id) DO NOTHING;
