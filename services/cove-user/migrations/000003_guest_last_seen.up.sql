-- Guest cleanup (#436): cove-user deletes guest profiles nobody has used for
-- 30 days. last_seen_at records the latest day a user made an authenticated
-- request; TouchLastSeen writes it at most once a day per user.
--
-- Existing rows start at the migration time, so no guest is deleted until it
-- has been idle for 30 days after this ships.

ALTER TABLE profile.users ADD COLUMN last_seen_at timestamptz NOT NULL DEFAULT now();

-- The cleanup query only scans guests.
CREATE INDEX users_guest_last_seen_idx ON profile.users (last_seen_at) WHERE is_guest;
