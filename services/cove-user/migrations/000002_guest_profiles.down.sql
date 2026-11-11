-- Rows without a username can't satisfy NOT NULL, so they are deleted first.
-- Their flags, favorites, follows, interests and activity cascade with them.
DELETE FROM profile.users WHERE username IS NULL;

ALTER TABLE profile.users DROP COLUMN is_guest;
ALTER TABLE profile.users ALTER COLUMN username SET NOT NULL;
