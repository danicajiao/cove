-- Guest profiles (#431): an anonymous Firebase user gets a profile row with no
-- username, so guests can save interests and post activity before signing up.
-- Signing up links a real login to the same Firebase UID, so the row carries
-- over; the username is set afterwards with PATCH /users/me.
--
-- username stays UNIQUE; Postgres allows any number of NULLs under it.
-- is_guest mirrors the gateway's X-Cove-Guest header and lets cleanup tell an
-- abandoned guest from a linked user who hasn't picked a username yet.

ALTER TABLE profile.users ALTER COLUMN username DROP NOT NULL;
ALTER TABLE profile.users ADD COLUMN is_guest boolean NOT NULL DEFAULT false;
