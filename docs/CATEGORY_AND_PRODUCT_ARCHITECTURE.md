# Category and Product Architecture

> **Status:** Planned design. The current app uses a flat, hardcoded category set. This document describes the post-migration model in Postgres — built alongside `cove-product` in Phase 3.

## Contents

- [Overview](#overview)
- [Category hierarchy](#category-hierarchy)
- [Facets and filters, not categories](#facets-and-filters-not-categories)
- [Products](#products)
- [Product variants](#product-variants)
- [Product details (polymorphic)](#product-details-polymorphic)
- [Full-text search](#full-text-search)
- [Indexes by query pattern](#indexes-by-query-pattern)
- [User-facing flows mapped to queries](#user-facing-flows-mapped-to-queries)
- [What's deliberately not modeled](#whats-deliberately-not-modeled)
- [References](#references)

---

## Overview

Cove's catalog has two related modeling problems that pull in different directions:

1. **Categories** need to nest arbitrarily deep (Produce → Vegetables → Root Vegetables) and support fast "give me everything in this subtree" queries. The right Postgres feature for this is `ltree`.
2. **Products** vary wildly in shape (a jar of honey has different attributes than a hand-thrown ceramic mug). The right Postgres feature for this is JSONB for the varying parts, normalized columns for the universal ones.

This doc covers both, plus the third related question: how to model SKU-level variations (sizes, weights, colors) without forcing every variation to be its own product.

For the overall service layout and database topology, see [Marketplace Architecture](MARKETPLACE_ARCHITECTURE.md). For Postgres mechanics (operators, indexes, JSONB syntax), see [Postgres Primer](POSTGRES_PRIMER.md).

---

## Category hierarchy

### Decision: `ltree`

The `categories` table uses Postgres's `ltree` extension to store the path from root to leaf in a single column:

```sql
CREATE EXTENSION IF NOT EXISTS ltree;

CREATE TABLE product.categories (
    id   uuid  PRIMARY KEY DEFAULT gen_random_uuid(),
    name text  NOT NULL,
    path ltree NOT NULL UNIQUE                       -- e.g. 'produce.dairy.cheese'
);

CREATE INDEX ON product.categories USING GIST  (path);
CREATE INDEX ON product.categories USING BTREE (path);
```

Each category's `path` is a dot-separated chain of labels representing its position in the tree. Labels must be `[A-Za-z0-9_]+` (no spaces, no hyphens), so display names like "Cheese & Dairy" get mapped to `cheese_and_dairy` for the path while the user-facing label lives in `name`.

### Why not denormalized ancestor arrays?

The Firestore version of this doc used a denormalized approach: a `parent_id` reference, an `ancestors` array, a `path` string, and a `level` integer — all updated together every time the tree changed.

| Aspect | `ltree` | Ancestor arrays |
|---|---|---|
| "All descendants of X" | `WHERE path <@ 'produce'` (indexed) | `WHERE 'produce' = ANY(ancestors)` (indexed if GIN) |
| "Direct children of X" | `WHERE path ~ 'produce.*{1}'` | `WHERE parent_id = X` |
| "Breadcrumb path to X" | `WHERE path @> X.path ORDER BY nlevel(path)` | Fetch each ancestor by ID |
| Rename / move a node | Update one row's `path`, descendants update via trigger or manual cascade | Update every descendant's `ancestors` array |
| Add a new level | No data changes — just insert the row | No data changes |
| Schema complexity | One column (`path`) | Four fields, all must stay in sync |
| Query expressiveness | Built-in operators for every traversal | Hand-rolled for anything beyond direct children |

**Why `ltree` wins for Cove:**
- One column does the work of four; nothing to keep in sync
- Built-in operators for every category traversal pattern we care about
- The denormalization that ancestor arrays buy (faster "is X an ancestor of Y" queries) isn't a meaningful win at Cove's data scale

**When you'd pick ancestor arrays instead:** if the chosen ORM/migration tooling didn't support `ltree` well, or if the tree was so large that the GiST index on `path` started underperforming a GIN index on an array. Neither applies here — `goose`/`golang-migrate` handle `ltree` fine and Cove's category count will be small enough that index choice is invisible.

### Example hierarchy

Cove's expected category tree (illustrative — actual taxonomy locked when first vendors onboard):

```
food (level 0)
├── produce
│   ├── vegetables
│   │   ├── root_vegetables
│   │   └── leafy_greens
│   └── fruits
├── dairy
│   ├── cheese
│   └── yogurt
└── pantry
    ├── honey
    └── preserves

crafts (level 0)
├── ceramics
├── textiles
└── woodwork

apparel (level 0)
├── clothing
└── accessories
```

`path` values are the dot-separated chains: `food.produce.vegetables.root_vegetables`, `crafts.ceramics`, etc.

### Common category queries

```sql
-- Top-level categories (Home screen entry points)
SELECT * FROM product.categories WHERE nlevel(path) = 1 ORDER BY name;

-- Direct children of a category (browse one level deeper)
SELECT * FROM product.categories WHERE path ~ 'food.produce.*{1}';

-- All descendants at any depth (e.g. "show me everything under produce")
SELECT * FROM product.categories WHERE path <@ 'food.produce';

-- Breadcrumb: ancestors of a specific category, root first
SELECT * FROM product.categories
WHERE path @> (SELECT path FROM product.categories WHERE id = $1)
ORDER BY nlevel(path);

-- Parent of a given category (one step up)
SELECT * FROM product.categories
WHERE path = subpath(
    (SELECT path FROM product.categories WHERE id = $1),
    0,
    nlevel((SELECT path FROM product.categories WHERE id = $1)) - 1
);

-- Move a subtree (e.g. reorganize `food.preserves` under `food.pantry`)
UPDATE product.categories
SET path = 'food.pantry.preserves' || subpath(path, 2)
WHERE path <@ 'food.preserves';
```

See [Postgres Primer](POSTGRES_PRIMER.md) for the full `ltree` operator reference.

---

## Facets and filters, not categories

The single most important modeling principle in this doc:

> **Categories define *what* a product is. Attributes define *how it differs from others in the same category*.**

When a new way to slice the catalog comes up — gender, dietary preference, certifications, season, region — it goes on the product as an attribute, **not** as a separate branch of the category tree.

### Why this matters

Consider apparel with three gender labels (Men, Women, Kids). The naive approach builds three branches:

```
Men > Clothing > Shirts
Women > Clothing > Shirts
Kids > Clothing > Shirts
```

That model collapses immediately when:
- A product is unisex — must be duplicated under multiple branches
- You want to show "All Shirts" — three subtrees to merge
- You add a fourth gender label — every existing category needs a new branch
- Display order, images, and translations now have to stay synced across the branches

The same problem appears with dietary attributes (Vegan Cheese, Vegan Dairy, Vegan Pantry — vs Cheese, Dairy, Pantry that any product can be tagged vegan within), certifications (Organic Produce vs Produce that can be filtered to organic), seasons, regional origin, and so on.

### The pattern

One category tree describes *what* a product is. Attributes are columns or JSONB keys on `products` that get used as filter facets at query time.

```sql
-- Apparel example: gender as attribute
SELECT * FROM product.products
WHERE category_id = (SELECT id FROM product.categories WHERE path = 'apparel.clothing.shirts')
  AND attributes @> '{"gender": "men"}';

-- Cross-category facet: anything organic, regardless of what kind of product
SELECT * FROM product.products
WHERE attributes @> '{"certifications": ["organic"]}';

-- Cross-category facet within a category subtree: organic produce
SELECT p.*
FROM product.products p
JOIN product.categories c ON c.id = p.category_id
WHERE c.path <@ 'food.produce'
  AND p.attributes @> '{"certifications": ["organic"]}';
```

The `attributes` column is JSONB with a GIN index, so containment queries (`@>`) are fast even on large catalogs. See [Postgres Primer](POSTGRES_PRIMER.md) for the indexing details.

### What goes in `attributes` vs a dedicated column

A field belongs as a top-level column on `products` when:
- Every product has it (e.g. `name`, `price_cents`, `vendor_id`)
- It's used in JOINs or ORDER BY (e.g. `created_at`, `category_id`)
- It needs a foreign key (e.g. `vendor_id`, `category_id`)

A field belongs in `attributes` JSONB when:
- It varies by product type (gender for apparel, flower source for honey)
- It's used as a filter facet (containment queries) but not for JOINs
- The set of valid keys evolves without schema migrations

---

## Products

```sql
CREATE TABLE product.products (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id   uuid        NOT NULL REFERENCES vendor.vendors(id),
    category_id uuid        NOT NULL REFERENCES product.categories(id),
    name        text        NOT NULL,
    description text,
    price_cents integer     NOT NULL,
    attributes  jsonb       NOT NULL DEFAULT '{}',   -- filterable facets (see Facets section)
    search_vec  tsvector    GENERATED ALWAYS AS (
        to_tsvector('english', coalesce(name, '') || ' ' || coalesce(description, ''))
    ) STORED,
    is_active   boolean     NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now()
);
```

Every product has a `price_cents` and `category_id`. Variations (different sizes, colors, weights) live in `product_variants` rather than as separate products. Type-specific extended attributes that don't make sense to filter on (ingredient lists, care instructions, brewing notes) live in `product_details`. Images live in `product_media` — exactly one `primary` image (shown in list views) and zero or more `gallery` images (detail carousel); see [Media Architecture](MEDIA_ARCHITECTURE.md) for the full storage + transformation + serving pipeline.

### Example rows

```sql
-- A jar of wildflower honey
INSERT INTO product.products (vendor_id, category_id, name, description, price_cents, attributes) VALUES (
    'vendor_smith_apiary_id',
    'category_food_pantry_honey_id',
    'Wildflower Honey',
    'Raw, unfiltered wildflower honey from local hives.',
    1299,
    '{
        "certifications": ["raw", "local"],
        "diet": ["vegetarian"],
        "flower_source": "wildflower"
    }'
);

-- A men's cotton t-shirt
INSERT INTO product.products (vendor_id, category_id, name, description, price_cents, attributes) VALUES (
    'vendor_threadworks_id',
    'category_apparel_clothing_shirts_id',
    'Classic Cotton Tee',
    'Locally screen-printed cotton t-shirt.',
    2999,
    '{
        "gender": "men",
        "brand": "Threadworks",
        "tags": ["casual", "summer"]
    }'
);
```

The `attributes` JSONB doesn't have a fixed schema — each product type writes the keys that make sense for it. The application layer (or a future admin UI) validates which keys are valid for which category, but Postgres doesn't enforce that.

---

## Product variants

Variants represent SKU-level differences that don't justify being separate products: the same wildflower honey in 8oz, 16oz, and 32oz jars; the same t-shirt in S/M/L and black/white.

```sql
CREATE TABLE product.product_variants (
    id          uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id  uuid    NOT NULL REFERENCES product.products(id) ON DELETE CASCADE,
    sku         text    UNIQUE,
    options     jsonb   NOT NULL,                    -- {"size": "M", "color": "black"}
    price_cents integer,                             -- NULL means inherit products.price_cents
    is_active   boolean NOT NULL DEFAULT true
);

CREATE INDEX ON product.product_variants (product_id);
```

`options` is a JSONB object naming the dimensions for this variant. Different product types name different dimensions:

```sql
-- Honey variants: size only
INSERT INTO product.product_variants (product_id, sku, options, price_cents) VALUES
    ('product_honey_id', 'HONEY-8OZ',  '{"size": "8oz"}',  799),
    ('product_honey_id', 'HONEY-16OZ', '{"size": "16oz"}', 1299),
    ('product_honey_id', 'HONEY-32OZ', '{"size": "32oz"}', 2299);

-- T-shirt variants: size × color
INSERT INTO product.product_variants (product_id, sku, options, price_cents) VALUES
    ('product_tee_id', 'TEE-S-BLK',  '{"size": "S", "color": "black"}', NULL),  -- NULL = inherit base price
    ('product_tee_id', 'TEE-M-BLK',  '{"size": "M", "color": "black"}', NULL),
    ('product_tee_id', 'TEE-S-WHT',  '{"size": "S", "color": "white"}', NULL);
```

The product itself owns the "base" price and image; variants override price when needed and (in a future enhancement) can override images. The iOS app shows the product card with the base price and lets the user pick a variant on the detail screen.

### Why JSONB on `options` and not separate columns

The dimensions vary by product type (size for honey, size+color for shirts, color+material for ceramics). A normalized schema would need a junction table or a wide nullable schema. JSONB stays compact and supports containment queries if needed (e.g. "all variants where size = S"):

```sql
SELECT * FROM product.product_variants WHERE options @> '{"size": "S"}';
```

If specific dimensions become highly queryable across all product types, they can be promoted to dedicated columns later.

---

## Product details (polymorphic)

`product_details` holds the long-form, type-specific data that doesn't fit on `products` and doesn't filter cleanly. Examples:

- **Honey:** floral notes, harvest date, hive location, full extraction process
- **Cheese:** milk source, aging duration, pasteurization status, rind type
- **Apparel:** material composition, care instructions, origin country
- **Ceramics:** clay type, glaze description, firing temperature

### Decision: single table with JSONB

```sql
CREATE TABLE product.product_details (
    product_id uuid  PRIMARY KEY REFERENCES product.products(id) ON DELETE CASCADE,
    payload    jsonb NOT NULL
);

CREATE INDEX ON product.product_details USING GIN (payload);
```

One row per product, keyed by `product_id`. The `payload` column stores whatever shape that product type needs.

```sql
-- Honey details
INSERT INTO product.product_details (product_id, payload) VALUES (
    'product_honey_id',
    '{
        "harvest_date": "2026-04-15",
        "extraction": "cold_pressed",
        "floral_notes": "wildflower meadow",
        "hive_location": "Smith Apiary, North Pasture"
    }'
);

-- Cheese details
INSERT INTO product.product_details (product_id, payload) VALUES (
    'product_cheese_id',
    '{
        "milk_source": "sheep",
        "aging_months": 6,
        "pasteurization": "raw",
        "rind": "natural"
    }'
);
```

### Why JSONB and not per-type tables (`coffee_product_details`, `apparel_product_details`)

| Aspect | Single JSONB table | Per-type tables |
|---|---|---|
| Adding a new product type | Just write the new payload shape — no migration | New `CREATE TABLE`, new migration, new schema row |
| Adding a field to an existing type | Just include it in new rows | `ALTER TABLE` with default |
| Querying across types | Single query | Union or per-type queries |
| Type-safe schema at the DB level | None — application validates | Strong column-level types |
| Required-field enforcement | None — application validates | NOT NULL constraints |
| Joining details into product responses | Single LEFT JOIN | LEFT JOIN per known type, or polymorphism in app code |
| Indexing | GIN on payload — works across types | B-tree per column per table |

**Why JSONB wins for Cove:**
- Product types will evolve organically as new vendor categories come on (a new bakery brings a new "baked goods" type with proofing times and crumb descriptions). With per-type tables, every new vendor type is a migration.
- The detail payload is read whole — there's no use case for joining honey details with cheese details. The "single query for all types" advantage isn't load-bearing.
- The type-safety loss is fine here. Details are read-mostly display data, not validation-critical.
- Migrations are expensive; payload evolution is free.

**When you'd pick per-type tables instead:** if the detail data drove transactions (orders, inventory, payments) where missing-fields-as-NULLs would corrupt downstream logic. That's not the case for v1.

### How `attributes` and `payload` differ

It's reasonable to ask why both exist:

| | `products.attributes` (JSONB) | `product_details.payload` (JSONB) |
|---|---|---|
| What it stores | Filter facets — short, structured values used in queries | Long-form display data — descriptions, dates, locations |
| Indexed | GIN on `attributes` (containment queries) | GIN on `payload` (less heavily used) |
| Query pattern | `WHERE attributes @> '{"gender": "men"}'` | `SELECT payload FROM product_details WHERE product_id = $1` |
| When loaded | On every product list response | Only on product detail screens |

In practice: if you might filter on it, it goes in `attributes`. If it's there to display on a detail screen, it goes in `payload`.

---

## Full-text search

`products.search_vec` is a generated `tsvector` column populated automatically from `name` and `description`:

```sql
search_vec tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(name, '') || ' ' || coalesce(description, ''))
) STORED;

CREATE INDEX ON product.products USING GIN (search_vec);
```

Search query:

```sql
SELECT id, name FROM product.products
WHERE is_active = true
  AND search_vec @@ websearch_to_tsquery('english', $1)
ORDER BY ts_rank(search_vec, websearch_to_tsquery('english', $1)) DESC
LIMIT 25;
```

`websearch_to_tsquery` is forgiving of user-typed input (handles phrases like `"raw honey"`, negations like `organic -processed`, and never throws on malformed queries). See [Postgres Primer](POSTGRES_PRIMER.md) for FTS details and ranking strategies.

---

## Indexes by query pattern

| Query pattern | Index used |
|---|---|
| Browse direct children of a category | `product.categories USING GIST (path)` — handles `path ~ 'food.produce.*{1}'` |
| Browse all products in a category subtree | `product.products (category_id) WHERE is_active = true` (partial) + GIST on category path for the subtree expansion |
| Filter by attribute (`{"gender": "men"}`, `{"certifications": ["organic"]}`) | `product.products USING GIN (attributes)` |
| Filter by price range | `product.products (price_cents)` |
| Filter by vendor | `product.products (vendor_id)` |
| Full-text search | `product.products USING GIN (search_vec)` |
| Variant lookup by SKU | `product.product_variants (sku)` (UNIQUE constraint implies B-tree index) |
| Variant filter by options | `product.product_variants USING GIN (options)` |
| Product details fetch | `product.product_details (product_id)` (PRIMARY KEY) |

For combined queries (e.g. "organic produce under $20"), Postgres uses bitmap index scans to AND the relevant indexes. The query planner picks which indexes to combine based on selectivity statistics — keep them fresh with `ANALYZE` after bulk loads.

---

## User-facing flows mapped to queries

### Home screen → top-level categories

```sql
SELECT id, name FROM product.categories WHERE nlevel(path) = 1 ORDER BY name;
```

### Category browse → products in this subtree

```sql
SELECT
    p.id, p.name, p.price_cents,
    m.media_key AS primary_image_key,
    m.width  AS primary_image_width,
    m.height AS primary_image_height
FROM product.products p
JOIN product.categories c ON c.id = p.category_id
LEFT JOIN LATERAL (
    SELECT media_key, width, height
    FROM product.product_media
    WHERE product_id = p.id AND role = 'primary'
    LIMIT 1
) m ON TRUE
WHERE c.path <@ $1                     -- the selected category's path
  AND p.is_active
ORDER BY p.created_at DESC
LIMIT 50;
```

### Apply filter facets

```sql
SELECT
    p.id, p.name, p.price_cents,
    m.media_key AS primary_image_key,
    m.width  AS primary_image_width,
    m.height AS primary_image_height
FROM product.products p
JOIN product.categories c ON c.id = p.category_id
LEFT JOIN LATERAL (
    SELECT media_key, width, height
    FROM product.product_media
    WHERE product_id = p.id AND role = 'primary'
    LIMIT 1
) m ON TRUE
WHERE c.path <@ $1                     -- category subtree
  AND p.attributes @> $2               -- e.g. '{"certifications": ["organic"]}'
  AND p.price_cents BETWEEN $3 AND $4
  AND p.is_active
ORDER BY p.created_at DESC;
```

In both queries the application layer (`cove-product`) turns each `primary_image_key` into a set of signed imgproxy variant URLs (`thumb`, `sm`, `md`) before returning the response — see [Media Architecture](MEDIA_ARCHITECTURE.md).

### Product detail page (single round trip)

```sql
SELECT
    p.id, p.name, p.description, p.price_cents, p.attributes,
    v.id AS vendor_id, v.name AS vendor_name,
    c.path AS category_path,
    pd.payload AS details,
    (
        SELECT json_agg(json_build_object(
            'id', pv.id, 'sku', pv.sku, 'options', pv.options,
            'price_cents', COALESCE(pv.price_cents, p.price_cents)
        ))
        FROM product.product_variants pv
        WHERE pv.product_id = p.id AND pv.is_active
    ) AS variants,
    (
        SELECT json_agg(json_build_object(
            'media_key', pm.media_key, 'role', pm.role, 'sort_order', pm.sort_order,
            'alt_text', pm.alt_text, 'width', pm.width, 'height', pm.height
        ) ORDER BY pm.sort_order)
        FROM product.product_media pm
        WHERE pm.product_id = p.id
    ) AS media
FROM product.products p
JOIN vendor.vendors        v  ON v.id = p.vendor_id
JOIN product.categories    c  ON c.id = p.category_id
LEFT JOIN product.product_details pd ON pd.product_id = p.id
WHERE p.id = $1;
```

One query returns everything the detail screen needs. The `cove-product` handler post-processes the `media` array, signing the 5-variant set for each item before returning the JSON.

---

## What's deliberately not modeled

Each of these belongs in a future phase:

- **Inventory and stock counts** — not in v1; no order management
- **Reviews and ratings** — out of scope per Phase 0 epic
- **Wish lists separate from favorites** — favorites already exist in `user.favorites`
- **Product status workflows beyond `is_active`** — no draft/published/archived states yet
- **Vendor-driven promotions or sale pricing** — `price_cents` is canonical; no historical pricing
- **Multi-currency** — `price_cents` assumed USD until international scope

---

## References

- [Marketplace Architecture](MARKETPLACE_ARCHITECTURE.md) — service layout, database topology, where this schema lives
- [Media Architecture](MEDIA_ARCHITECTURE.md) — product image storage, transformation, serving, variant catalog, vendor upload pipeline
- [Postgres Primer](POSTGRES_PRIMER.md) — `ltree` operators, JSONB syntax, FTS, indexes
- [Backend Infrastructure](BACKEND_INFRASTRUCTURE.md) — cluster + deployment model
