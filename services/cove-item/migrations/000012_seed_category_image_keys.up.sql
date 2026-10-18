-- Seed image_key for every category card background in Garage (cove-media).
-- All 242 categories, at every level, have an image under images/categories/.
--
-- Key format mirrors the ltree path: dots become hyphens, underscores are kept.
--   food                    → images/categories/food.jpg
--   food.baked_goods        → images/categories/food-baked_goods.jpg
--   food.protein.beef       → images/categories/food-protein-beef.jpg
--
-- This is the single source of truth for the naming rule — clients read
-- image_key from the API and never derive it themselves.

UPDATE catalog.categories
SET    image_key = 'images/categories/' || replace(path::text, '.', '-') || '.jpg';
