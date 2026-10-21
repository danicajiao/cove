ALTER TABLE catalog.categories DROP COLUMN wide_image_key;

UPDATE catalog.categories
SET    image_key = 'images/categories/' || replace(path::text, '.', '-') || '.jpg';
