-- catalog schema: categories, signals, items, availability, entity_signals, media
--
-- Consolidates 000003_catalog + 000005_category_leaf_constraint +
-- 000006_category_delete_integrity + 000007_schema_enhancements (catalog parts),
-- and the category image columns from the old 000011 and 000013:
--
--   catalog.categories   — is_leaf, image_key and wide_image_key baked in;
--                          mark_parent_non_leaf + delete-integrity triggers
--                          installed from the start
--   catalog.signals      — has_expiry + is_active baked in from the start
--   catalog.items        — producer_id nullable (brand-only and secondhand items);
--                          brand, is_active + search_vec GENERATED column present
--   catalog.availability — listing_source, listing_url, is_active baked in;
--                          item_id FK is ON DELETE RESTRICT from the start
--   catalog.entity_signals — cert_number, cert_expires_at, verified_by baked in
--   catalog.media        — unchanged (exclusive arc structure)
--
-- The is_leaf backfill UPDATE from old 000005 is omitted: on a fresh database the
-- categories_mark_parent_non_leaf trigger handles it on each seed INSERT.
--
-- Run order: after 000001_setup, and after the cove-directory migrations
-- (items, availability, entity_signals and media reference directory tables).

-- image_key is the card image (every category); wide_image_key is the 4:1
-- onboarding image (level 1 only). Both are set in 000003.
CREATE TABLE catalog.categories (
    id             uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    name           text    NOT NULL,
    path           ltree   NOT NULL UNIQUE,
    is_leaf        boolean NOT NULL DEFAULT true,
    image_key      text,
    wide_image_key text
);

CREATE INDEX ON catalog.categories USING GIST  (path);
CREATE INDEX ON catalog.categories USING BTREE (path);

-- Trigger: when a child category is inserted, mark its parent as non-leaf.
CREATE FUNCTION catalog.mark_parent_non_leaf() RETURNS trigger AS $$
BEGIN
    UPDATE catalog.categories
    SET is_leaf = false
    WHERE path = subpath(NEW.path, 0, nlevel(NEW.path) - 1)
      AND nlevel(NEW.path) > 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER categories_mark_parent_non_leaf
    AFTER INSERT ON catalog.categories
    FOR EACH ROW EXECUTE FUNCTION catalog.mark_parent_non_leaf();

-- Trigger: block deletion of a category that still has children.
CREATE FUNCTION catalog.prevent_non_leaf_category_delete() RETURNS trigger AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM catalog.categories child
        WHERE child.path ~ (OLD.path::text || '.*{1}')::lquery
    ) THEN
        RAISE EXCEPTION 'cannot delete category "%" because it still has children', OLD.path;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER categories_prevent_non_leaf_delete
    BEFORE DELETE ON catalog.categories
    FOR EACH ROW EXECUTE FUNCTION catalog.prevent_non_leaf_category_delete();

-- Trigger: after a leaf is deleted, re-evaluate whether its parent is now a leaf.
CREATE FUNCTION catalog.recheck_parent_leaf() RETURNS trigger AS $$
BEGIN
    IF nlevel(OLD.path) > 1 THEN
        UPDATE catalog.categories
        SET is_leaf = NOT EXISTS (
            SELECT 1 FROM catalog.categories child
            WHERE child.path ~ (subpath(OLD.path, 0, nlevel(OLD.path) - 1)::text || '.*{1}')::lquery
        )
        WHERE path = subpath(OLD.path, 0, nlevel(OLD.path) - 1);
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER categories_recheck_parent_leaf
    AFTER DELETE ON catalog.categories
    FOR EACH ROW EXECUTE FUNCTION catalog.recheck_parent_leaf();

-- Signal taxonomy — one row per signal type, referenced by entity_signals.
-- has_expiry + is_active baked in (was added in old 000007_schema_enhancements).
CREATE TABLE catalog.signals (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    code                text        NOT NULL UNIQUE,
    name                text        NOT NULL,
    description         text,
    verification_method text        NOT NULL,
        -- 'directory_crossref' | 'api_lookup' | 'manual_review' | 'kyc'
    weight              numeric     NOT NULL DEFAULT 1,
    has_expiry          boolean     NOT NULL DEFAULT false,
    is_active           boolean     NOT NULL DEFAULT true
);

CREATE TABLE catalog.items (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    producer_id uuid        REFERENCES directory.producers(id),
        -- nullable: brand-only and secondhand items have no producer
    category_id uuid        NOT NULL REFERENCES catalog.categories(id),
    name        text        NOT NULL,
    brand       text,
        -- plain brand name for items whose brand isn't a producer
    description text,
    price_cents integer,
    attributes  jsonb       NOT NULL DEFAULT '{}',
    details     jsonb       NOT NULL DEFAULT '{}',
    search_vec  tsvector    GENERATED ALWAYS AS (
        to_tsvector('english', coalesce(name, '') || ' ' || coalesce(description, ''))
    ) STORED,
    is_active   boolean     NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ON catalog.items USING GIN (search_vec);
CREATE INDEX ON catalog.items USING GIN (attributes);
CREATE INDEX ON catalog.items (category_id) WHERE is_active = true;
CREATE INDEX ON catalog.items (producer_id);

-- Trigger: enforce that items can only reference leaf categories.
CREATE FUNCTION catalog.enforce_leaf_category() RETURNS trigger AS $$
BEGIN
    IF NOT (SELECT is_leaf FROM catalog.categories WHERE id = NEW.category_id) THEN
        RAISE EXCEPTION 'category_id must reference a leaf category (path: %)',
            (SELECT path FROM catalog.categories WHERE id = NEW.category_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER items_enforce_leaf_category
    BEFORE INSERT OR UPDATE ON catalog.items
    FOR EACH ROW EXECUTE FUNCTION catalog.enforce_leaf_category();

-- Many-to-many: an item can be sold at multiple places.
-- listing_source, listing_url, is_active baked in (old 000007).
-- item_id FK is ON DELETE RESTRICT (changed from CASCADE in old 000007).
CREATE TABLE catalog.availability (
    item_id        uuid        NOT NULL REFERENCES catalog.items(id)     ON DELETE RESTRICT,
    place_id       uuid        NOT NULL REFERENCES directory.places(id) ON DELETE CASCADE,
    listing_source text        NOT NULL DEFAULT 'place_listed'
        CHECK (listing_source IN ('producer_listed', 'place_listed')),
    listing_url    text,
    is_active      boolean     NOT NULL DEFAULT true,
    created_at     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (item_id, place_id)
);

CREATE INDEX ON catalog.availability (place_id) WHERE is_active = true;

-- Polymorphic trust signal attachment — links a signal to exactly one entity
-- via an exclusive arc (exactly one of producer_id, place_id, item_id is set).
-- cert_number, cert_expires_at, verified_by baked in (old 000007).
CREATE TABLE catalog.entity_signals (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    signal_id       uuid        NOT NULL REFERENCES catalog.signals(id),
    producer_id     uuid        REFERENCES directory.producers(id) ON DELETE CASCADE,
    place_id        uuid        REFERENCES directory.places(id)    ON DELETE CASCADE,
    item_id         uuid        REFERENCES catalog.items(id)       ON DELETE CASCADE,
    status          text        NOT NULL DEFAULT 'pending',
        -- 'verified' | 'pending' | 'community_vouched'
    verified_at     timestamptz,
    verified_via    text,
    cert_number     text,
    cert_expires_at timestamptz,
    verified_by     text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    CHECK (num_nonnulls(producer_id, place_id, item_id) = 1)
);

CREATE INDEX ON catalog.entity_signals (producer_id);
CREATE INDEX ON catalog.entity_signals (place_id);
CREATE INDEX ON catalog.entity_signals (item_id);

-- Polymorphic media — links an image to exactly one entity.
CREATE TABLE catalog.media (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    producer_id uuid        REFERENCES directory.producers(id) ON DELETE CASCADE,
    place_id    uuid        REFERENCES directory.places(id)    ON DELETE CASCADE,
    item_id     uuid        REFERENCES catalog.items(id)       ON DELETE CASCADE,
    media_key   text        NOT NULL,
    role        text        NOT NULL DEFAULT 'gallery',
        -- 'primary' | 'gallery' | 'logo'
    sort_order  integer     NOT NULL DEFAULT 0,
    alt_text    text,
    width       integer     NOT NULL,
    height      integer     NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CHECK (num_nonnulls(producer_id, place_id, item_id) = 1)
);

CREATE INDEX ON catalog.media (item_id, sort_order);
CREATE INDEX ON catalog.media (place_id);
CREATE INDEX ON catalog.media (producer_id);

-- cove_catalog owns the full catalog
GRANT SELECT, INSERT, UPDATE, DELETE ON catalog.categories     TO cove_catalog;
GRANT SELECT, INSERT, UPDATE, DELETE ON catalog.signals        TO cove_catalog;
GRANT SELECT, INSERT, UPDATE, DELETE ON catalog.items          TO cove_catalog;
GRANT SELECT, INSERT, UPDATE, DELETE ON catalog.availability   TO cove_catalog;
GRANT SELECT, INSERT, UPDATE, DELETE ON catalog.entity_signals TO cove_catalog;
GRANT SELECT, INSERT, UPDATE, DELETE ON catalog.media          TO cove_catalog;

-- cove_user reads items and categories for favorites/interests cross-schema FKs
GRANT SELECT, REFERENCES ON catalog.items      TO cove_user;
GRANT SELECT, REFERENCES ON catalog.categories TO cove_user;

-- cove_directory reads catalog for place and producer pages (signals, items sold
-- at a place, their images) and for matching places to categories
GRANT SELECT ON catalog.categories, catalog.signals, catalog.entity_signals,
                catalog.items, catalog.availability, catalog.media TO cove_directory;
