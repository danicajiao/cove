-- Extensions are already created in the CNPG cluster bootstrap
-- (postInitApplicationSQL), but IF NOT EXISTS makes this idempotent.
CREATE EXTENSION IF NOT EXISTS ltree;

CREATE SCHEMA IF NOT EXISTS catalog;

-- Roles and their search_path defaults are managed in the CNPG cluster
-- bootstrap (postInitApplicationSQL) — both CREATE ROLE and ALTER ROLE
-- require superuser, which the app user does not have.
--
-- Run order across services: cove-directory, then cove-catalog, then cove-user.
-- catalog tables reference directory.producers and directory.places.

-- Schema-level grants — app owns the schemas it creates, so GRANT is permitted.
GRANT USAGE ON SCHEMA catalog TO cove_catalog;

-- cove-directory reads catalog (signals, items sold at a place, categories for
-- place matching); cove-user references items and categories.
GRANT USAGE ON SCHEMA catalog TO cove_directory, cove_user;
