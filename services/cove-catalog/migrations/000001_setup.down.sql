REVOKE USAGE ON SCHEMA catalog FROM cove_catalog, cove_directory, cove_user;

DROP SCHEMA IF EXISTS catalog CASCADE;

-- Roles and search_path defaults are cluster-level objects managed by
-- the CNPG bootstrap — not dropped or reset here.
