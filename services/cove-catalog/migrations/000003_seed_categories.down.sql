-- Remove all seeded categories.
-- Disable the prevent_non_leaf_category_delete trigger so we can bulk-delete
-- without having to walk the tree leaf-by-leaf. Items are already gone at this
-- point (000005.down runs before this), so there are no FK violations to worry about.
ALTER TABLE catalog.categories DISABLE TRIGGER categories_prevent_non_leaf_delete;
DELETE FROM catalog.categories;
ALTER TABLE catalog.categories ENABLE TRIGGER categories_prevent_non_leaf_delete;
