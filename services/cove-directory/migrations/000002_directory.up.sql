-- directory schema: producers and places
--
-- Consolidates original 000002_directory + 000007_schema_enhancements (directory parts):
--   - slug, city, state, zip, website_url, is_active, updated_at baked in from the start
--   - address and location are nullable (the placeholder seed places are online-only)
--   - trust_score retained for compatibility (ranking signal for future use)
--   - place_categories tags places with categories directly
--
-- Run order: after 000001_setup (extensions + schema + grants).

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

-- Categories a place is tagged with directly: cuisine tags, and places with no
-- items (a venue tagged music). Item roll-up through catalog.availability
-- covers the rest.
--
-- category_id is a plain uuid, not a foreign key, so directory never depends on
-- catalog at migration time. The trigger below rejects IDs that aren't in
-- catalog.categories when a tag is written; it runs at write time, after both
-- schemas exist.
CREATE TABLE directory.place_categories (
    place_id    uuid        NOT NULL REFERENCES directory.places(id) ON DELETE CASCADE,
    category_id uuid        NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (place_id, category_id)
);

CREATE INDEX ON directory.place_categories (category_id);

CREATE FUNCTION directory.check_place_category() RETURNS trigger AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM catalog.categories WHERE id = NEW.category_id) THEN
        RAISE EXCEPTION 'unknown category_id % for place %', NEW.category_id, NEW.place_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER place_categories_check_category
    BEFORE INSERT OR UPDATE ON directory.place_categories
    FOR EACH ROW EXECUTE FUNCTION directory.check_place_category();

-- cove_directory owns the directory schema
GRANT SELECT, INSERT, UPDATE, DELETE ON directory.producers        TO cove_directory;
GRANT SELECT, INSERT, UPDATE, DELETE ON directory.places           TO cove_directory;
GRANT SELECT, INSERT, UPDATE, DELETE ON directory.place_categories TO cove_directory;

-- cove_catalog references producers and places (items, availability, signals,
-- media) and reads place tags for discovery
GRANT SELECT, REFERENCES ON directory.producers, directory.places TO cove_catalog;
GRANT SELECT             ON directory.place_categories            TO cove_catalog;

-- cove_user references producers and places for follows
GRANT SELECT, REFERENCES ON directory.producers, directory.places TO cove_user;
