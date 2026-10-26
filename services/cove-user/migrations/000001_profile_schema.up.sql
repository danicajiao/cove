-- profile schema: users, user_flags, favorites, follows, interests, activity
--
-- Consolidates original 000001_user_schema + 000002_profile_schema_v2 + 000003_username_unique
-- and the user_flags table from the old 000002_interests_onboarded into a single
-- clean starting state:
--
--   profile.users       — surrogate UUID primary key (id), auth_uid (provider-agnostic),
--                         unique username, no email (Firebase owns auth data)
--   profile.user_flags,
--   profile.favorites,
--   profile.follows,
--   profile.interests,
--   profile.activity    — user_id uuid FK referencing profile.users(id)
--
-- Run order across services: cove-directory, then cove-catalog, then cove-user.
-- Depends on catalog.items, catalog.categories, directory.producers and
-- directory.places existing.

CREATE SCHEMA IF NOT EXISTS profile;

GRANT USAGE ON SCHEMA profile TO cove_user;

CREATE TABLE profile.users (
    id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_uid   text        NOT NULL UNIQUE,  -- constraint: users_auth_uid_key
    username   text        NOT NULL UNIQUE,  -- constraint: users_username_key
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Generic per-user flags table. Each row records that a named flag was set for
-- a user, along with when. Presence of a row is the flag — no value column needed.
-- Adding new flags requires no schema changes, only a new string constant in the service.
--
-- Current flags:
--   interests_onboarded — set when PUT /users/me/interests is called (even with an empty array)
CREATE TABLE profile.user_flags (
    user_id    uuid        NOT NULL REFERENCES profile.users(id) ON DELETE CASCADE,
    flag       text        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, flag)
);

CREATE TABLE profile.favorites (
    user_id    uuid        NOT NULL REFERENCES profile.users(id)   ON DELETE CASCADE,
    item_id    uuid        NOT NULL REFERENCES catalog.items(id)   ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, item_id)
);

CREATE INDEX ON profile.favorites (user_id, created_at DESC);

-- Follows target a producer OR a place — exclusive arc enforces exactly one.
CREATE TABLE profile.follows (
    user_id     uuid        NOT NULL REFERENCES profile.users(id)      ON DELETE CASCADE,
    producer_id uuid        REFERENCES directory.producers(id)         ON DELETE CASCADE,
    place_id    uuid        REFERENCES directory.places(id)            ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CHECK (num_nonnulls(producer_id, place_id) = 1)
);

CREATE INDEX ON profile.follows (user_id, created_at DESC);

-- Explicit onboarding interest picks — editable later in settings.
CREATE TABLE profile.interests (
    user_id     uuid        NOT NULL REFERENCES profile.users(id)       ON DELETE CASCADE,
    category_id uuid        NOT NULL REFERENCES catalog.categories(id),
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, category_id)
);

CREATE INDEX ON profile.interests (user_id);

-- Activity: implicit behavioral signals for recommendation ranking. Named
-- "activity" so "events" can mean real-world events at places.
-- activity_type: 'category_tap' | 'item_view' | 'result_dwell' | 'search'
CREATE TABLE profile.activity (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       uuid        NOT NULL REFERENCES profile.users(id) ON DELETE CASCADE,
    activity_type text        NOT NULL,
    category_id   uuid        REFERENCES catalog.categories(id),
    item_id       uuid        REFERENCES catalog.items(id),
    metadata      jsonb       NOT NULL DEFAULT '{}',
    created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ON profile.activity (user_id, created_at DESC);
CREATE INDEX ON profile.activity (user_id, category_id) WHERE category_id IS NOT NULL;
CREATE INDEX ON profile.activity (user_id, item_id)     WHERE item_id     IS NOT NULL;

GRANT SELECT, INSERT, UPDATE, DELETE ON profile.users     TO cove_user;
GRANT SELECT, INSERT, DELETE         ON profile.user_flags TO cove_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON profile.favorites TO cove_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON profile.follows   TO cove_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON profile.interests TO cove_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON profile.activity  TO cove_user;
