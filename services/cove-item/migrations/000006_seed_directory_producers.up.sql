-- Seed directory.producers with the four v1 placeholder brands.
-- Fixed UUIDs make this idempotent via ON CONFLICT DO NOTHING.

INSERT INTO directory.producers (id, name, slug, description, tier, city, state, location, website_url)
VALUES (
    'f1000001-c0ff-0000-0000-000000000001',
    'Ritual Coffee Roasters',
    'ritual-coffee-roasters',
    $d$A fully independent, woman-owned coffee sourcing and roasting company. Pioneer of specialty coffee on Valencia Street in San Francisco since 2005.$d$,
    'verified_business',
    'San Francisco',
    'CA',
    ST_Point(-122.4213, 37.7582)::geography,
    'https://ritualcoffee.com'
)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO directory.producers (id, name, slug, description, tier, city, state, location, website_url)
VALUES (
    'f1000001-c0ff-0000-0000-000000000002',
    'Onyx Coffee Lab',
    'onyx-coffee-lab',
    $d$Specialty coffee roaster in Springdale, Arkansas, built on direct relationships with farms, organic practices, and ethical trading.$d$,
    'verified_business',
    'Springdale',
    'AR',
    ST_Point(-94.1288, 36.1867)::geography,
    'https://onyxcoffeelab.com'
)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO directory.producers (id, name, slug, description, tier, website_url)
VALUES (
    'f1000001-c0ff-0000-0000-000000000003',
    'iets franz…',
    'iets-franz',
    $d$Modern athleisure label crafting elevated sportswear basics, fresh silhouettes, and technical fabrications.$d$,
    'verified_business',
    'https://www.urbanoutfitters.com/brands/iets-franz'
)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO directory.producers (id, name, slug, description, tier, website_url)
VALUES (
    'f1000001-c0ff-0000-0000-000000000004',
    'HOMESHAKE',
    'homeshake',
    $d$Peter Sagar, known as HOMESHAKE, is a Montreal-based musician making dreamy, lo-fi R&B.$d$,
    'individual_lister',
    'https://homeshake.bandcamp.com'
)
ON CONFLICT (slug) DO NOTHING;
