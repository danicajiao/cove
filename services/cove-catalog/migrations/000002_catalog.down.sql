-- Drop catalog tables and trigger functions in reverse dependency order.

-- Triggers are dropped automatically with their tables, but functions need explicit drops.
DROP TABLE IF EXISTS catalog.media;
DROP TABLE IF EXISTS catalog.entity_signals;
DROP TABLE IF EXISTS catalog.availability;
DROP TABLE IF EXISTS catalog.items;
DROP TABLE IF EXISTS catalog.signals;
DROP TABLE IF EXISTS catalog.categories;

DROP FUNCTION IF EXISTS catalog.enforce_leaf_category();
DROP FUNCTION IF EXISTS catalog.recheck_parent_leaf();
DROP FUNCTION IF EXISTS catalog.prevent_non_leaf_category_delete();
DROP FUNCTION IF EXISTS catalog.mark_parent_non_leaf();
