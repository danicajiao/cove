-- Remove in dependency order: place_categories and places reference producers.
-- cove-catalog and cove-user migrations must be down first (their tables
-- reference producers and places).
DROP TABLE IF EXISTS directory.place_categories;
DROP FUNCTION IF EXISTS directory.check_place_category();
DROP TABLE IF EXISTS directory.places;
DROP TABLE IF EXISTS directory.producers;
