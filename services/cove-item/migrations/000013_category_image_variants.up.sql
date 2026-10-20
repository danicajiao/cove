-- Split category images into two aspect-ratio variants in Garage (cove-media):
--
--   images/categories/card/  ~13:6 crop for every category (home shelf cards)
--   images/categories/wide/  4:1 crop for level 1 categories only (onboarding cards)
--
-- image_key keeps its meaning (the card image) and moves under card/.
-- wide_image_key is new and set only where nlevel(path) = 1.
--
-- Key format mirrors the ltree path: dots become hyphens, underscores are kept.
--   food               → images/categories/card/food.jpg, images/categories/wide/food.jpg
--   food.baked_goods   → images/categories/card/food-baked_goods.jpg
--
-- This replaces 000012 as the single source of truth for the naming rule —
-- clients read both keys from the API and never derive them.

ALTER TABLE catalog.categories ADD COLUMN wide_image_key TEXT;

UPDATE catalog.categories
SET    image_key = 'images/categories/card/' || replace(path::text, '.', '-') || '.jpg';

UPDATE catalog.categories
SET    wide_image_key = 'images/categories/wide/' || replace(path::text, '.', '-') || '.jpg'
WHERE  nlevel(path) = 1;
