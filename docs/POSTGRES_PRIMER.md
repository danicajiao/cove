# Postgres Primer

A focused ramp-up on the Postgres concepts Cove's backend depends on. The goal is not a comprehensive tutorial — it's the specific knowledge you need before Phase 3 schema work begins.

Assumed starting point: comfortable with Firestore, new to relational databases.

---

## The database layout

Cove runs one CNPG `Cluster` per service. Each cluster gets its own Postgres instance with a single database:

| CNPG Cluster | Database | Primary tables |
|---|---|---|
| `product-db` | `product` | `products`, `categories`, `producers`, `media_assets` |
| `user-db` | `user` | `users`, `addresses`, `follows` |

Within each database the default schema (`public`) is used — no schema prefixes needed. `SELECT * FROM products` just works inside the `product` database.

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

**When this matters for Cove:** CNPG provisions each database with a dedicated role. The `search_path` is set on that role so application queries never need to qualify schema names. The `ltree` and `pg_trgm` extensions land in `public` by default — no special path needed.

If you ever create a second schema (e.g., to isolate admin tables from the API surface), you'd update `search_path` on the role:

```sql
ALTER ROLE product_app SET search_path = app, public;
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
