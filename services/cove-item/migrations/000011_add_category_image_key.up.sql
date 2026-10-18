-- Add nullable image_key column to catalog.categories.
-- Stores the Garage object key for the category card background image,
-- e.g. "images/categories/food-coffee.jpg". Nullable: not every category
-- has a dedicated background image.
ALTER TABLE catalog.categories ADD COLUMN image_key TEXT;
