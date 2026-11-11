DROP INDEX IF EXISTS profile.users_guest_last_seen_idx;
ALTER TABLE profile.users DROP COLUMN last_seen_at;
