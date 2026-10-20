-- Write "care" categories as one word, matching Skincare and the paths.
UPDATE catalog.categories SET name = 'Plantcare' WHERE path = 'plants.plantcare';
UPDATE catalog.categories SET name = 'Bodycare'  WHERE path = 'beauty.bodycare';
UPDATE catalog.categories SET name = 'Haircare'  WHERE path = 'beauty.haircare';
