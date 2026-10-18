# Database Migrations

Operational runbook for running, debugging, and managing schema migrations against the `cove-db` CNPG cluster.

## Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Connecting to the cluster](#connecting-to-the-cluster)
- [Running migrations](#running-migrations)
- [Role management](#role-management)
- [Troubleshooting](#troubleshooting)

---

## Overview

Cove uses [golang-migrate](https://github.com/golang-migrate/migrate) for schema migrations. Each service owns its own migration directory:

| Service | Migrations path | Schemas owned |
|---|---|---|
| `cove-item` | `services/cove-item/migrations/` | `directory`, `catalog` |
| `cove-user` | `services/cove-user/migrations/` | `profile` |

Migrations are plain SQL files in numbered pairs (`000001_name.up.sql` / `000001_name.down.sql`). golang-migrate tracks the current version in a per-service table in the `public` schema of the `cove` database:

| Service | Tracking table |
|---|---|
| `cove-item` | `public.schema_migrations_cove_item` |
| `cove-user` | `public.schema_migrations_cove_user` |

Both services share the same `cove` database, so a separate table per service is required — a single shared `schema_migrations` table would conflict when the two services are at different migration versions. The table name is passed to golang-migrate via `x-migrations-table` in the connection string (see [Running migrations](#running-migrations)).

**cove-item migrations must run before cove-user** — the `profile` schema has cross-schema foreign keys into `catalog` and `directory`.

---

## Prerequisites

**Install the migrate CLI:**
```bash
brew install golang-migrate
```

**Verify kubectl is connected:**
```bash
kubectl get nodes
```

---

## Connecting to the cluster

The `cove-db` cluster is not publicly exposed — it only accepts connections from inside the cluster. Use `kubectl port-forward` to tunnel the Postgres port to your local machine.

**Staging:**
```bash
kubectl port-forward -n cove-staging svc/cove-db-rw 5432:5432
```

**Prod (use a different local port to avoid conflict if both are open):**
```bash
kubectl port-forward -n cove-prod svc/cove-db-rw 5433:5432
```

Leave the port-forward running in a separate terminal while you run migrations.

**Getting the app user password:**
```bash
# staging
kubectl get secret -n cove-staging cove-db-app \
  -o jsonpath='{.data.password}' | base64 -d

# prod
kubectl get secret -n cove-prod cove-db-app \
  -o jsonpath='{.data.password}' | base64 -d
```

---

## Running migrations

Run from the root of the `cove` repo with the port-forward active.

Each service uses its own tracking table via `x-migrations-table` — both services write to the same `cove` database, so without this flag they would share one `schema_migrations` table and conflict when migration versions don't align.

### Apply all pending migrations

```bash
# 1. cove-item (directory + catalog schemas)
migrate \
  -path services/cove-item/migrations \
  -database "postgres://app:<password>@localhost:5432/cove?sslmode=disable&x-migrations-table=schema_migrations_cove_item" \
  up

# 2. cove-user (profile schema) — run after cove-item
migrate \
  -path services/cove-user/migrations \
  -database "postgres://app:<password>@localhost:5432/cove?sslmode=disable&x-migrations-table=schema_migrations_cove_user" \
  up
```

### Roll back one step

```bash
migrate \
  -path services/cove-item/migrations \
  -database "postgres://app:<password>@localhost:5432/cove?sslmode=disable&x-migrations-table=schema_migrations_cove_item" \
  down 1
```

### Check current version

```bash
migrate \
  -path services/cove-item/migrations \
  -database "postgres://app:<password>@localhost:5432/cove?sslmode=disable&x-migrations-table=schema_migrations_cove_item" \
  version
```

### Verify applied schema (via psql)

```bash
# List schemas
kubectl exec -n cove-staging cove-db-1 -c postgres -- psql -U postgres -d cove -c "\dn"

# List tables in a schema
kubectl exec -n cove-staging cove-db-1 -c postgres -- psql -U postgres -d cove -c "\dt directory.*"
kubectl exec -n cove-staging cove-db-1 -c postgres -- psql -U postgres -d cove -c "\dt catalog.*"
kubectl exec -n cove-staging cove-db-1 -c postgres -- psql -U postgres -d cove -c "\dt profile.*"
```

---

## Role management

### Why roles are not in migration files

`CREATE ROLE` is an instance-level superuser operation. The `app` user that golang-migrate connects as is a regular database user with no `CREATEROLE` privilege — attempting it produces:

```
error: migration failed: permission denied to create role
```

Roles are managed separately via the CNPG cluster bootstrap (`postInitApplicationSQL` in `apps/cove/base/cove-db/cluster.yaml` in the homelab repo), which runs as superuser at cluster creation time.

**The boundary:**

| Object | Managed by | Privilege required |
|---|---|---|
| Roles (`cove_item`, `cove_user`) | CNPG `postInitApplicationSQL` | Superuser |
| Extensions (`postgis`, `ltree`) | CNPG `postInitApplicationSQL` | Superuser |
| Schemas, tables, grants | golang-migrate | App user |

### Accessing the superuser

CNPG's `postgres` superuser uses **peer authentication** inside the pod — no password is needed when connecting from within the same process. Use `kubectl exec` to connect:

```bash
kubectl exec -n cove-staging cove-db-1 -c postgres -- psql -U postgres -d cove
```

### Superuser-only operations

Both `CREATE ROLE` and `ALTER ROLE` require superuser privileges. Neither can run in migrations (the `app` user has neither `CREATEROLE` nor `ADMIN` on the service roles). Both live in `postInitApplicationSQL` in the homelab cluster.yaml.

### Manually provisioning roles (existing clusters)

`postInitApplicationSQL` only runs at cluster creation time. For existing clusters, roles and search paths must be created once manually:

```bash
kubectl exec -n <namespace> cove-db-1 -c postgres -- psql -U postgres -d cove -c "
DO \$\$ BEGIN CREATE ROLE cove_item WITH LOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END \$\$;
DO \$\$ BEGIN CREATE ROLE cove_user WITH LOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END \$\$;
ALTER ROLE cove_item SET search_path = catalog, directory, public;
ALTER ROLE cove_user  SET search_path = profile, public;
"
```

Verify roles exist and `search_path` defaults are set:
```bash
# Lists roles and attributes (does not show search_path)
kubectl exec -n <namespace> cove-db-1 -c postgres -- psql -U postgres -c "\du"

# Confirms search_path is set — search_path lives in pg_db_role_setting, not \du
kubectl exec -n <namespace> cove-db-1 -c postgres -- psql -U postgres -d cove -c \
  "SELECT rolname, setconfig FROM pg_roles r LEFT JOIN pg_db_role_setting s ON r.oid = s.setrole WHERE rolname IN ('cove_item', 'cove_user');"
```

Role passwords are managed via ESO → GCP Secret Manager and set with `ALTER ROLE` — they are never stored in migration files.

---

## Troubleshooting

### Dirty migration state

If a migration fails partway through, golang-migrate marks the version as `dirty` and refuses to run until it is resolved:

```
error: Dirty database version 1. Fix and force version.
```

**Check the state** (use the service-specific table name):
```bash
# cove-item
kubectl exec -n cove-staging cove-db-1 -c postgres -- psql -U postgres -d cove \
  -c "SELECT * FROM schema_migrations_cove_item;"

# cove-user
kubectl exec -n cove-staging cove-db-1 -c postgres -- psql -U postgres -d cove \
  -c "SELECT * FROM schema_migrations_cove_user;"
```

**Fix options:**

If the migration failed cleanly (Postgres rolled back the transaction — most DDL in Postgres is transactional), the database is actually in the prior good state. Clear the dirty record and rerun:

```bash
# Clear the dirty record (safe if the transaction rolled back)
kubectl exec -n cove-staging cove-db-1 -c postgres -- psql -U postgres -d cove \
  -c "DELETE FROM schema_migrations_cove_item;"  # or schema_migrations_cove_user

# Then rerun
migrate -path services/cove-item/migrations \
  -database "...&x-migrations-table=schema_migrations_cove_item" up
```

If the migration partially applied (some statements committed before the failure), use `migrate force <version>` to mark the version as clean, then manually fix the inconsistency before rerunning:

```bash
migrate -path services/cove-item/migrations \
  -database "...&x-migrations-table=schema_migrations_cove_item" force 1
```

### Permission denied errors

If migrate errors with `permission denied`, check which operation failed:

- **`permission denied to create role`** — role creation is in a migration file; it must move to the CNPG bootstrap. See [Role management](#role-management).
- **`permission denied for schema`** — the `app` user is missing a `GRANT USAGE` on that schema. Check that the setup migration applied cleanly.
- **`permission denied for table`** — the `app` user is missing table-level grants. Check that the relevant migration applied cleanly.
