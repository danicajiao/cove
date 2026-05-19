# Postgres Primer

A focused ramp-up on the Postgres concepts Cove's backend depends on. The goal is not a comprehensive tutorial — it's the specific knowledge you need before Phase 3 schema work begins.

Assumed starting point: comfortable with Firestore, new to relational databases.

## Contents

- [The database layout](#the-database-layout)
- [Schemas and search_path](#schemas-and-search_path)
- [Indexes: B-tree, GIN, and partial](#indexes-b-tree-gin-and-partial)
- [EXPLAIN ANALYZE](#explain-analyze)
- [Transactions and isolation levels](#transactions-and-isolation-levels)
- [JSONB](#jsonb)
- [Full-text search with tsvector and tsquery](#full-text-search-with-tsvector-and-tsquery)
- [Category hierarchy with ltree](#category-hierarchy-with-ltree)
- [Quick reference](#quick-reference)
- [Glossary](#glossary)

---

## The database layout

Cove runs one CNPG `Cluster` (`cove-db`) hosting a single database (`cove`). Inside that database, each service owns its own schema:

| Schema | Owning service | Primary tables |
|---|---|---|
| `product` | `cove-product` | `categories`, `products`, `product_variants`, `product_details` |
| `vendor` | `cove-vendor` (future) | `vendors` |
| `user` | `cove-user` | `users`, `favorites`, `follows` |

The `vendor` schema is pre-positioned in Phase 3 — it exists at the database level but no service formally owns it yet. `cove-product` and `cove-user` get read-only + FK reference grants; vendor data is seeded once during the Firestore migration and stays static until the `cove-vendor` service ships in a follow-up phase. See [Marketplace Architecture](MARKETPLACE_ARCHITECTURE.md) for the rationale.

Each service connects with a Postgres role whose `search_path` is set to its own schema, so application queries stay unqualified — `SELECT * FROM products` inside `cove-product` works without ever typing `product.products`. Cross-schema references (e.g., `user.favorites` → `product.products`, `product.products.vendor_id` → `vendor.vendors`) use real foreign keys, since all schemas live in the same database.

### Why one cluster, not one per service

The microservices-textbook answer is "one database per service." That trade-off is correct at FAANG scale where per-service teams, failure-isolation budgets, and compliance boundaries all matter. None of those conditions apply at Cove's v1 scale (one developer, one node, one product surface). What does apply is the cost of giving up referential integrity, JOINs, and atomic writes — every user-centric feature becomes a distributed systems problem when its references cross cluster boundaries. One cluster with schemas keeps logical service ownership while preserving Postgres's relational guarantees. See [Marketplace Architecture](MARKETPLACE_ARCHITECTURE.md) for the full rationale.

Compare to Firestore:

| Firestore | Postgres |
|---|---|
| Collection | Table |
| Document | Row |
| Field | Column |
| No schema enforcement | Column types enforced at write time |
| Schemaless | Schema-first |

---

## Schemas and search_path

A Postgres **schema** is a namespace inside a database — a way to group tables, functions, and types. Every database starts with a `public` schema.

```sql
-- These are equivalent inside the `product` database:
SELECT * FROM products;
SELECT * FROM public.products;
```

`search_path` is the ordered list of schemas Postgres checks when you use an unqualified name. The default is `public` first:

```sql
SHOW search_path;
-- "$user", public
```

**When this matters for Cove:** CNPG provisions the `cove` database, then bootstrap migrations create the `product`, `vendor`, and `user` schemas plus service roles for the services that exist (`cove_product`, `cove_user`). The `cove_vendor` role isn't created yet — the schema exists but no service owns it until the future `cove-vendor` service ships. The `ltree` extension lives in `public` (the chart default) so it's reachable from any schema.

```sql
-- Bootstrap sketch — runs once after the cluster comes up

-- Schemas first
CREATE SCHEMA product;
CREATE SCHEMA vendor;
CREATE SCHEMA "user";

-- Roles for services that exist in Phase 3
CREATE ROLE cove_product LOGIN PASSWORD :'product_password';
CREATE ROLE cove_user    LOGIN PASSWORD :'user_password';

-- Each role owns its schema
GRANT USAGE ON SCHEMA product TO cove_product;
GRANT USAGE ON SCHEMA "user"  TO cove_user;

-- cove_product reads vendor.vendors for product responses + FK validation
GRANT USAGE      ON SCHEMA vendor TO cove_product;
GRANT SELECT     ON vendor.vendors TO cove_product;
GRANT REFERENCES ON vendor.vendors TO cove_product;

-- cove_user reads product.products and vendor.vendors for JOIN reads
-- and FK validation (favorites + follows)
GRANT USAGE      ON SCHEMA product, vendor TO cove_user;
GRANT SELECT     ON product.products, vendor.vendors TO cove_user;
GRANT REFERENCES ON product.products, vendor.vendors TO cove_user;

ALTER ROLE cove_product SET search_path = product, public;
ALTER ROLE cove_user    SET search_path = "user", public;
```

Cross-schema foreign keys are the unlock that makes the single-cluster model practical:

```sql
-- A favorite that physically lives in the `user` schema but references
-- a row in the `product` schema. Postgres enforces this — INSERT fails
-- if the product doesn't exist; deleting the product CASCADEs the favorite.
CREATE TABLE "user".favorites (
    uid        text NOT NULL REFERENCES "user".users(uid)      ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES product.products(id)   ON DELETE CASCADE,
    PRIMARY KEY (uid, product_id)
);
```

---

## Indexes: B-tree, GIN, and partial

Postgres has several index types. Three matter for Cove:

### B-tree (the default)

B-tree handles equality, range queries, and sorting. It's what you get with a plain `CREATE INDEX`.

```sql
-- Good: equality and range on a scalar column
CREATE INDEX ON products (category_id);
CREATE INDEX ON products (price_cents);
CREATE INDEX ON products (created_at DESC);

-- Postgres uses the index for:
SELECT * FROM products WHERE category_id = $1;
SELECT * FROM products WHERE price_cents BETWEEN 1000 AND 5000;
SELECT * FROM products ORDER BY created_at DESC LIMIT 20;
```

B-tree cannot index inside JSONB values or full-text vectors — use GIN for those.

### GIN (Generalized Inverted Index)

GIN indexes the *contents* of a composite value — every key in a JSONB object, every lexeme in a tsvector, every element in an array. It's slower to build and update than B-tree but the only practical choice for:

- JSONB containment queries (`@>`)
- Full-text search (`@@`)
- Array membership

```sql
-- Index JSONB attributes for containment queries
CREATE INDEX ON products USING GIN (attributes);

-- Index the full-text search vector
CREATE INDEX ON products USING GIN (search_vec);

-- Postgres uses the index for:
SELECT * FROM products WHERE attributes @> '{"diet": "organic"}';
SELECT * FROM products WHERE search_vec @@ to_tsquery('english', 'honey');
```

### Partial indexes

A partial index only covers rows that match a `WHERE` clause. Smaller, faster, and the right tool when a large fraction of rows are irrelevant to most queries.

```sql
-- Only index active products — inactive ones are never shown to users
CREATE INDEX ON products (category_id) WHERE is_active = true;

-- Only index unread notifications
CREATE INDEX ON notifications (user_id, created_at DESC) WHERE read_at IS NULL;
```

The query must include the same condition to use the index:

```sql
-- Uses the partial index
SELECT * FROM products WHERE category_id = $1 AND is_active = true;

-- Falls back to seq scan — condition doesn't match the partial index filter
SELECT * FROM products WHERE category_id = $1;
```

---

## EXPLAIN ANALYZE

`EXPLAIN ANALYZE` runs a query and shows the actual execution plan with real timings. Use it whenever a query is slower than expected.

```sql
EXPLAIN ANALYZE
SELECT p.id, p.name, p.price_cents
FROM products p
WHERE p.category_id = 'abc123'
  AND p.is_active = true
ORDER BY p.price_cents
LIMIT 20;
```

Example output:

```
Limit  (cost=0.43..18.64 rows=20 width=48) (actual time=0.051..0.142 rows=20 loops=1)
  ->  Index Scan using products_category_id_idx on products p
        (cost=0.43..91.20 rows=100 width=48) (actual time=0.049..0.131 rows=20 loops=1)
        Index Cond: (category_id = 'abc123'::uuid)
        Filter: (is_active = true)
Planning Time: 0.3 ms
Execution Time: 0.2 ms
```

**How to read it:**

| Term | What it means |
|---|---|
| `cost=X..Y` | Planner estimate. First number = startup cost, second = total cost. Arbitrary units. |
| `actual time=X..Y` | Real wall-clock milliseconds. First = first row, second = all rows. |
| `rows=N` | Estimated (in cost) vs actual (in actual time) row count. Big gaps here mean stale statistics — run `ANALYZE products`. |
| `loops=N` | How many times this node ran. Multiply `actual time` by `loops` for true cost. |
| `Index Scan` | Used an index — good. |
| `Seq Scan` | Scanned the full table. Fine on small tables; investigate on large ones. |
| `Filter` | Applied after index lookup, not part of the index condition. Rows removed here are wasted work — consider a better index. |
| `Bitmap Heap Scan` | Used an index to collect matching row locations, then fetched them. Common when many rows match. |

**Common patterns to look for:**

```sql
-- High rows estimate vs actual: run ANALYZE
ANALYZE products;

-- Seq Scan on a large table: missing index
CREATE INDEX ON products (producer_id);

-- Index Scan but Filter removes most rows: wrong index or need partial index
CREATE INDEX ON products (producer_id) WHERE is_active = true;
```

---

## Transactions and isolation levels

A **transaction** is a group of operations that either all succeed or all fail. In Postgres, every statement runs inside a transaction — even bare `INSERT`/`UPDATE` statements are auto-committed.

```sql
-- Explicit transaction: reserve a product and create a notification atomically
BEGIN;

UPDATE products
SET reserved_by = $1, reserved_at = now()
WHERE id = $2 AND reserved_by IS NULL;

INSERT INTO notifications (user_id, type, payload)
VALUES ($1, 'reservation_confirmed', jsonb_build_object('product_id', $2));

COMMIT;  -- both writes land, or neither does
```

If anything between `BEGIN` and `COMMIT` fails, `ROLLBACK` undoes everything.

### Isolation levels

Isolation controls what a transaction can see from concurrent transactions. Postgres has four levels; two matter in practice:

| Level | Default? | What it sees |
|---|---|---|
| `READ COMMITTED` | ✅ yes | Only committed data. Each statement sees a fresh snapshot. Two reads of the same row in one transaction can return different values if another transaction commits between them. |
| `REPEATABLE READ` | No | Snapshot taken at transaction start. Same row returns the same value throughout the transaction, even if another transaction commits. |
| `SERIALIZABLE` | No | Full serializability — transactions behave as if they ran one at a time. Highest protection, occasional retry on conflict. |

**Read committed is almost always right for Cove.** The main exception is multi-step read-then-write operations where consistency across reads matters:

```sql
-- Repeatable read: ensure the product count doesn't change between the
-- check and the insert
BEGIN ISOLATION LEVEL REPEATABLE READ;

SELECT count(*) FROM products WHERE producer_id = $1;
-- ... application logic based on the count ...
INSERT INTO products (...) VALUES (...);

COMMIT;
```

### Watch out for: long transactions

A transaction holds locks and prevents Postgres from vacuuming dead rows for its duration. Keep transactions short — open them, do the work, commit immediately. Never hold a transaction open waiting for user input or an external API call.

---

## JSONB

JSONB stores JSON as a binary decomposed structure — indexed, queryable, and faster than `json` (which stores raw text). Use it for attributes that vary by product type so the `products` table doesn't need 50 nullable columns.

```sql
-- products table: fixed columns for things every product has,
-- JSONB for the rest
CREATE TABLE products (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name        text NOT NULL,
    price_cents integer NOT NULL,
    category_id uuid NOT NULL REFERENCES categories(id),
    attributes  jsonb NOT NULL DEFAULT '{}',
    is_active   boolean NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- Honey: {"diet": "organic", "weight_g": 500, "flower_source": "wildflower"}
-- Cheese: {"diet": "vegetarian", "weight_g": 200, "milk_type": "sheep"}
-- Vegetables: {"diet": "organic", "unit": "bunch"}
```

### Operators

| Operator | Returns | Meaning |
|---|---|---|
| `attributes -> 'diet'` | `jsonb` | Get value as JSON (`"organic"`) |
| `attributes ->> 'diet'` | `text` | Get value as text (`organic`) — use this in `WHERE` |
| `attributes @> '{"diet": "organic"}'` | `boolean` | Does attributes contain this JSON? |
| `attributes ? 'weight_g'` | `boolean` | Does the key exist? |

```sql
-- All organic products (GIN index on attributes makes this fast)
SELECT * FROM products WHERE attributes @> '{"diet": "organic"}';

-- Products under 300g (cast the text value to integer for comparison)
SELECT * FROM products WHERE (attributes ->> 'weight_g')::integer < 300;

-- Products that have a flower_source attribute at all
SELECT * FROM products WHERE attributes ? 'flower_source';

-- Build a JSONB object in a query
SELECT jsonb_build_object(
    'id', id,
    'name', name,
    'diet', attributes ->> 'diet'
) FROM products;
```

### GIN index on JSONB

```sql
-- Covers all @> containment queries and ? key-exists queries
CREATE INDEX ON products USING GIN (attributes);
```

### JSONB vs a normalized table

Use JSONB when:
- Attributes vary significantly by category (honey has `flower_source`, vegetables don't)
- You query by value (`WHERE attributes @> '{"diet": "organic"}'`) but don't JOIN on individual attributes
- The attribute set evolves without schema migrations

Use a normalized column when:
- Every row has the value (e.g., `price_cents`, `name`)
- You JOIN on it or use it in ORDER BY / GROUP BY
- You need foreign key constraints on it

---

## Full-text search with tsvector and tsquery

Postgres has built-in full-text search. `tsvector` is a pre-processed representation of a document (normalized words + positions). `tsquery` is a search expression. The `@@` operator checks if a query matches a vector.

### Setting it up

Store the search vector as a generated column so it stays in sync with the source columns automatically:

```sql
ALTER TABLE products ADD COLUMN search_vec tsvector
    GENERATED ALWAYS AS (
        to_tsvector('english',
            coalesce(name, '') || ' ' ||
            coalesce(description, '')
        )
    ) STORED;

CREATE INDEX ON products USING GIN (search_vec);
```

### Querying

```sql
-- Simple word search
SELECT id, name FROM products
WHERE search_vec @@ to_tsquery('english', 'honey');

-- AND: both words must appear
SELECT id, name FROM products
WHERE search_vec @@ to_tsquery('english', 'raw & honey');

-- OR: either word
SELECT id, name FROM products
WHERE search_vec @@ to_tsquery('english', 'honey | jam');

-- Prefix match (useful for autocomplete)
SELECT id, name FROM products
WHERE search_vec @@ to_tsquery('english', 'hon:*');

-- Ranked results — ts_rank scores how well a document matches
SELECT id, name, ts_rank(search_vec, query) AS rank
FROM products, to_tsquery('english', 'organic & honey') query
WHERE search_vec @@ query
ORDER BY rank DESC
LIMIT 10;
```

### websearch_to_tsquery

For user-typed search strings, `websearch_to_tsquery` is more forgiving than `to_tsquery` — it handles phrases, quoted strings, and doesn't throw on invalid syntax:

```sql
-- Handles "raw honey" as a phrase, "organic -processed" as negation
SELECT id, name FROM products
WHERE search_vec @@ websearch_to_tsquery('english', $1);
```

---

## Category hierarchy with ltree

`ltree` is a Postgres extension for representing and querying tree-structured data. Categories in Cove form a hierarchy (Produce → Vegetables → Root Vegetables), and `ltree` makes ancestor/descendant queries fast without recursive CTEs.

### Enable the extension

```sql
CREATE EXTENSION IF NOT EXISTS ltree;
```

CNPG provisioning will handle this — the extension is declared in the `Cluster` spec.

### Schema

```sql
CREATE TABLE categories (
    id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    path ltree NOT NULL UNIQUE  -- e.g. 'produce.vegetables.root_vegetables'
);

CREATE INDEX ON categories USING GIST (path);
CREATE INDEX ON categories USING BTREE (path);

-- Products reference categories by id, not by path
-- (path can change on rename; id never changes)
ALTER TABLE products ADD CONSTRAINT fk_category
    FOREIGN KEY (category_id) REFERENCES categories(id);
```

### Path notation

Labels are dot-separated. Each label must be alphanumeric + underscores.

```
produce
produce.vegetables
produce.vegetables.root_vegetables
produce.dairy
produce.dairy.cheese
```

### Operators

| Operator | Meaning | Example |
|---|---|---|
| `path <@ 'produce'` | Is path a descendant of `produce`? | `produce.dairy` → true |
| `path @> 'produce.dairy.cheese'` | Is path an ancestor of the given path? | `produce` → true |
| `path ~ 'produce.*{1}'` | lquery pattern match (one level deep) | `produce.vegetables` → true |
| `path ? ARRAY[...]` | Matches any of the lquery patterns? | |
| `nlevel(path)` | Depth of the path | `produce.dairy` → 2 |
| `subpath(path, 0, 2)` | First 2 labels | `produce.vegetables.root` → `produce.vegetables` |

### Common queries

```sql
-- All descendants of produce (any depth)
SELECT * FROM categories WHERE path <@ 'produce';

-- Direct children of produce only (one level deeper)
SELECT * FROM categories WHERE path ~ 'produce.*{1}';

-- All products in any vegetable subcategory
SELECT p.*
FROM products p
JOIN categories c ON c.id = p.category_id
WHERE c.path <@ 'produce.vegetables';

-- Breadcrumb: ancestors of a given category, root first
SELECT * FROM categories
WHERE path @> (SELECT path FROM categories WHERE id = $1)
ORDER BY nlevel(path);

-- Subtree root: strip the last label to get the parent
SELECT subpath(path, 0, nlevel(path) - 1) AS parent_path
FROM categories
WHERE id = $1;
```

### Why not a `parent_id` adjacency list?

A `parent_id` column requires a recursive CTE (`WITH RECURSIVE`) to traverse the tree. Recursive CTEs work but are verbose and harder to index efficiently. `ltree` turns any depth traversal into a single indexed operator — cleaner to write, faster to execute.

---

## Quick reference

```sql
-- Most common operations

-- Containment (needs GIN index on attributes)
WHERE attributes @> '{"diet": "organic"}'

-- Text value from JSONB
WHERE (attributes ->> 'weight_g')::integer < 300

-- Full-text search (needs GIN index on search_vec)
WHERE search_vec @@ websearch_to_tsquery('english', $1)

-- All products in a category subtree (needs GIST index on path)
JOIN categories c ON c.id = p.category_id WHERE c.path <@ 'produce'

-- Direct children of a category
WHERE path ~ 'produce.*{1}'

-- Read query plan
EXPLAIN ANALYZE SELECT ...

-- Refresh statistics after large data loads
ANALYZE products;
```

---

## Glossary

Quick lookups for terms used throughout. For full context, see the corresponding sections above.

**B-tree** — The default Postgres index type. Used for equality, range queries, and sorting on scalar columns. Created with a plain `CREATE INDEX`.

**Cross-schema FK** — A foreign key whose target column lives in a different schema in the same database (e.g. `"user".favorites.product_id` → `product.products(id)`). Works natively; foundational to Cove's single-cluster-schemas-per-service topology.

**EXPLAIN ANALYZE** — A Postgres command that runs a query and reports the actual execution plan with wall-clock timings. The first tool to reach for when a query is slower than expected.

**Generated column** — A column whose value is computed by an expression over other columns in the same row. `STORED` keeps the result on disk so it can be indexed. Used for `search_vec` to keep it in sync with `name` + `description` automatically.

**GIN** — Generalized Inverted Index. Indexes the *contents* of composite values: JSONB keys, array elements, tsvector lexemes. Required for `@>` containment, `?` key-exists, and `@@` full-text matches.

**GiST** — Generalized Search Tree. The index type used by `ltree` for hierarchical operators (`<@`, `@>`, `~`).

**JSONB** — Binary-stored, queryable, indexable JSON. Preferred over `json` for any column you'll query. Operators: `->` (get as JSONB), `->>` (get as text), `@>` (contains), `?` (key exists).

**ltree** — Postgres extension that stores hierarchical labels as a single dot-separated column (`food.produce.honey`). Operators include `<@` (is descendant of), `@>` (is ancestor of), `~` (matches lquery pattern), `nlevel()` (depth).

**Partial index** — An index with a `WHERE` clause covering only matching rows. Smaller, faster, and the right tool when most rows are irrelevant to most queries (e.g., active products only).

**Read committed** — Postgres's default isolation level. Each statement sees a fresh snapshot of committed data. Two reads of the same row in one transaction may return different values if another transaction committed in between.

**Repeatable read** — An isolation level where the entire transaction sees the snapshot taken at its start. Use when you need consistency across multiple reads in one transaction.

**Role** — A Postgres "user" with login and permission grants. Services connect as their own role (`cove_product`, `cove_user`) so schema ownership is enforced at the database level.

**Schema** — A namespace inside a Postgres database that groups tables, functions, and types. Cove uses one schema per service (`product`, `vendor`, `user`) within a single `cove` database.

**search_path** — Ordered list of schemas Postgres checks for unqualified names. Each service's role has its own schema first, so application queries stay unqualified (`SELECT * FROM products` works inside `cove-product` because `search_path = product, public`).

**Serializable** — The strictest isolation level — transactions behave as if they ran one at a time. Rarely needed; comes with occasional retry on conflict.

**tsquery** — A search expression parsed from user input (via `to_tsquery` or `websearch_to_tsquery`). Combined with `@@` to match against a tsvector.

**tsvector** — Pre-processed representation of a document (normalized lexemes + positions) used for full-text search. Typically stored as a generated column from `name` + `description` and indexed with GIN.

**websearch_to_tsquery** — A forgiving tsquery parser for user-typed search input. Handles phrases (`"raw honey"`), negations (`organic -processed`), and never throws on invalid syntax. Use this for app search bars; use `to_tsquery` for programmatic queries.

