-- Seed catalog.items — four v1 placeholder products.
-- Producer UUIDs are hardcoded (seeded by cove-directory 000003_seed_producers).
-- Category UUIDs are looked up by path.
-- Dollar-quote tags: $d$ = description text, $j$ = jsonb literals.

INSERT INTO catalog.items (id, producer_id, category_id, name, description, price_cents, attributes, details)
SELECT
    'f3000001-1234-0000-0000-000000000001',
    'f1000001-c0ff-0000-0000-000000000001',
    id,
    'Colombia Familia Montano',
    $d$Carefully roasted by Ritual Coffee Roasters. Grown by Familia Montano in the Huila Department of Colombia using a Fully Washed process. Tasting notes: bing cherries, sugarcane, milk chocolate, and citrus.$d$,
    2300,
    $j${"roastery": "Ritual Coffee Roasters", "process": "Fully Washed", "origin_country": "Colombia", "producer": "Familia Montano", "region": "Palermo, Huila"}$j$::jsonb,
    $j${"about": "Both internationally renowned and a local favorite, Ritual Coffee is a fully independent, woman-owned coffee sourcing and roasting company. Pioneer of the specialty coffee movement on Valencia Street in San Francisco since 2005.", "origin": [{"title": "Country", "content": "Colombia"}, {"title": "Variety", "content": "Colombia, Castillo"}, {"title": "Producer", "content": "Familia Montano"}, {"title": "Region", "content": "Palermo, Huila"}, {"title": "Process", "content": "Fully Washed"}]}$j$::jsonb
FROM catalog.categories WHERE path = 'food.coffee.whole_bean'
ON CONFLICT (id) DO NOTHING;

INSERT INTO catalog.items (id, producer_id, category_id, name, description, price_cents, attributes, details)
SELECT
    'f3000001-1234-0000-0000-000000000002',
    'f1000001-c0ff-0000-0000-000000000002',
    id,
    'Southern Weather Blend',
    $d$Blended and roasted by Onyx Coffee Lab. Features coffees from Colombia and Ethiopia with notes of milk chocolate, plum, candied walnuts, and juicy citrus acidity.$d$,
    2300,
    $j${"roastery": "Onyx Coffee Lab", "process": "Fully Washed", "origin_country": "Colombia, Ethiopia", "altitude_m": 1850}$j$::jsonb,
    $j${"about": "Onyx Coffee Lab is built on direct relationships with farms. Set on the East side of Springdale, Arkansas, it is a passion project from owners Jon and Andrea, committed to organic practices and ethical trading.", "origin": [{"title": "Country", "content": "Colombia, Ethiopia"}, {"title": "Process", "content": "Fully Washed"}, {"title": "Altitude", "content": "1850m"}, {"title": "Producer", "content": "Various Small Holder Producers"}]}$j$::jsonb
FROM catalog.categories WHERE path = 'food.coffee.whole_bean'
ON CONFLICT (id) DO NOTHING;

INSERT INTO catalog.items (id, producer_id, category_id, name, description, price_cents, attributes, details)
SELECT
    'f3000001-1234-0000-0000-000000000003',
    'f1000001-c0ff-0000-0000-000000000003',
    id,
    'Balloon Cargo Pant',
    $d$Light and easy Y2K tech pants in a baggy parachute fit. Slouchy at the low drawcord waist and loose through the leg with a gathered drawcord at the hem. 100% Cotton.$d$,
    7500,
    $j${"brand": "iets franz…", "material": "100% Cotton", "fit": "Baggy", "rise": "Low"}$j$::jsonb,
    $j${"about": "Crafting modern athleisure pieces, iets franz… is the go-to for elevated sportswear basics, fresh silhouettes, and technical fabrications.", "specifications": [{"title": "Features", "content": ["Baggy parachute pants", "Low-rise waist"]}, {"title": "Content + Care", "content": ["100% Cotton", "Machine wash", "Imported"]}, {"title": "Size + Fit", "content": ["Rise: 11.5\"", "Inseam: 30\"", "Leg opening: 10\""]}]}$j$::jsonb
FROM catalog.categories WHERE path = 'apparel.unisex.bottoms'
ON CONFLICT (id) DO NOTHING;

INSERT INTO catalog.items (id, producer_id, category_id, name, description, price_cents, attributes, details)
SELECT
    'f3000001-1234-0000-0000-000000000004',
    'f1000001-c0ff-0000-0000-000000000004',
    id,
    'Under The Weather',
    $d$HOMESHAKE fifth studio album, written in 2019 during a long period of introspection in Montreal. Includes high-quality download in MP3, FLAC, and more.$d$,
    900,
    $j${"artist": "HOMESHAKE", "album": "Under The Weather", "format": "cassette"}$j$::jsonb,
    $j${"about": "Peter Sagar wrote the majority of Under the Weather in 2019, when he was going through a long, unrelenting period of sadness. The album captures that quiet and restraint.", "tracklist": [{"title": "Wake Up!", "durationSec": 22}, {"title": "Feel Better", "durationSec": 254}, {"title": "Vacuum", "durationSec": 182}]}$j$::jsonb
FROM catalog.categories WHERE path = 'music.recorded.cassette'
ON CONFLICT (id) DO NOTHING;
