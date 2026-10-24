-- Seed directory.places — one online place per producer.
-- Producer UUIDs are hardcoded (guaranteed to exist after 000003_seed_producers).

INSERT INTO directory.places (id, run_by_producer_id, name, slug, type, website_url)
VALUES (
    'f2000001-cafe-0000-0000-000000000001',
    'f1000001-c0ff-0000-0000-000000000001',
    'Ritual Coffee Roasters',
    'ritual-coffee-roasters-online',
    'online',
    'https://ritualcoffee.com'
)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO directory.places (id, run_by_producer_id, name, slug, type, website_url)
VALUES (
    'f2000001-cafe-0000-0000-000000000002',
    'f1000001-c0ff-0000-0000-000000000002',
    'Onyx Coffee Lab',
    'onyx-coffee-lab-online',
    'online',
    'https://onyxcoffeelab.com'
)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO directory.places (id, run_by_producer_id, name, slug, type, website_url)
VALUES (
    'f2000001-cafe-0000-0000-000000000003',
    'f1000001-c0ff-0000-0000-000000000003',
    'iets franz…',
    'iets-franz-online',
    'online',
    'https://www.urbanoutfitters.com/brands/iets-franz'
)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO directory.places (id, run_by_producer_id, name, slug, type, website_url)
VALUES (
    'f2000001-cafe-0000-0000-000000000004',
    'f1000001-c0ff-0000-0000-000000000004',
    'HOMESHAKE Bandcamp',
    'homeshake-bandcamp',
    'online',
    'https://homeshake.bandcamp.com'
)
ON CONFLICT (slug) DO NOTHING;
