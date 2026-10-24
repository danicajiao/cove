-- Extensions are already created in the CNPG cluster bootstrap
-- (postInitApplicationSQL), but IF NOT EXISTS makes this idempotent.
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE SCHEMA IF NOT EXISTS directory;

-- Roles and their search_path defaults are managed in the CNPG cluster
-- bootstrap (postInitApplicationSQL) — both CREATE ROLE and ALTER ROLE
-- require superuser, which the app user does not have.
--
-- Run order across services: cove-directory first, then cove-catalog, then
-- cove-user. Nothing in directory references another schema with a foreign key.

-- Schema-level grants — app owns the schemas it creates, so GRANT is permitted.
GRANT USAGE ON SCHEMA directory TO cove_directory;

-- cove-catalog references producers and places (items, availability, signals,
-- media); cove-user references them for follows.
GRANT USAGE ON SCHEMA directory TO cove_catalog, cove_user;
