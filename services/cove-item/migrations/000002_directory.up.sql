-- directory schema: producers and places
--
-- Consolidates original 000002_directory + 000007_schema_enhancements (directory parts):
--   - slug, city, state, zip, website_url, is_active, updated_at baked in from the start
--   - address and location are nullable (the placeholder seed places are online-only)
--   - trust_score retained for compatibility (ranking signal for future use)
--
-- directory.place_categories is created in 000003, after catalog.categories.
--
-- Run order: after 000001_setup (extensions + schemas + grants).

CREATE TABLE directory.producers (
    id           uuid                  PRIMARY KEY DEFAULT gen_random_uuid(),
    name         text                  NOT NULL,
    slug         text                  UNIQUE,
    description  text,
    tier         text                  NOT NULL DEFAULT 'individual_lister',
        -- 'verified_business' | 'individual_lister'
    trust_score  numeric               NOT NULL DEFAULT 0,
    city         text,
    state        text,
    zip          text,
    address      text,
    location     geography(Point,4326),
    website_url  text,
    is_active    boolean               NOT NULL DEFAULT true,
    created_at   timestamptz           NOT NULL DEFAULT now(),
    updated_at   timestamptz           NOT NULL DEFAULT now()
);

CREATE INDEX ON directory.producers (slug);
CREATE INDEX ON directory.producers USING GIST (location);
CREATE INDEX ON directory.producers (trust_score DESC);
CREATE INDEX ON directory.producers (is_active) WHERE is_active = true;

CREATE TABLE directory.places (
    id                 uuid                  PRIMARY KEY DEFAULT gen_random_uuid(),
    run_by_producer_id uuid                  REFERENCES directory.producers(id),
    name               text                  NOT NULL,
    description        text,
    slug               text                  UNIQUE,
    type               text                  NOT NULL CHECK (type IN (
                           'cafe', 'restaurant', 'bar', 'bakery', 'dessert_shop', 'shop',
                           'gallery', 'studio', 'market', 'venue', 'taproom',
                           -- Temporary: only the placeholder seed places use 'online'.
                           -- Removed with the Denver seed data in #406.
                           'online')),
    city               text,
    state              text,
    zip                text,
    address            text,
    location           geography(Point,4326),
    website_url        text,
    trust_score        numeric               NOT NULL DEFAULT 0,
    is_active          boolean               NOT NULL DEFAULT true,
    created_at         timestamptz           NOT NULL DEFAULT now(),
    updated_at         timestamptz           NOT NULL DEFAULT now()
);

CREATE INDEX ON directory.places (run_by_producer_id);
CREATE INDEX ON directory.places USING GIST (location);
CREATE INDEX ON directory.places (trust_score DESC);
CREATE INDEX ON directory.places (slug);
CREATE INDEX ON directory.places (is_active) WHERE is_active = true;

-- cove_item owns directory writes for v1 (until cove-directory ships)
GRANT SELECT, INSERT, UPDATE, DELETE ON directory.producers TO cove_item;
GRANT SELECT, INSERT, UPDATE, DELETE ON directory.places    TO cove_item;
GRANT REFERENCES                     ON directory.producers TO cove_item;
GRANT REFERENCES                     ON directory.places    TO cove_item;

-- cove_user reads directory for favorites/follows cross-schema FKs
GRANT SELECT     ON directory.producers, directory.places TO cove_user;
GRANT REFERENCES ON directory.producers, directory.places TO cove_user;
