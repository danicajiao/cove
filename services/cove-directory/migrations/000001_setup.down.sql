REVOKE USAGE ON SCHEMA directory FROM cove_directory, cove_catalog, cove_user;

DROP SCHEMA IF EXISTS directory CASCADE;

-- Roles and search_path defaults are cluster-level objects managed by
-- the CNPG bootstrap — not dropped or reset here.
