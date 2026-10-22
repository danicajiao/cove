# Services

Backend services live here, using the `cove-<name>` convention (e.g.
`services/cove-api/`). The sibling `apps/` directory is reserved for client
applications (the iOS app today, a web client later).

| Service | Directory | Phase | Status |
|---|---|---|---|
| `cove-api` | [`cove-api/`](cove-api/) | 1 | Deployed |
| `cove-image` | [`cove-image/`](cove-image/) | 2 | Deployed |
| `cove-catalog` | [`cove-catalog/`](cove-catalog/) | 3 | Split out of `cove-item` (#413); deploys with #416 |
| `cove-directory` | [`cove-directory/`](cove-directory/) | 3 | Split out of `cove-item` (#413); deploys with #416 |
| `cove-user` | [`cove-user/`](cove-user/) | 3 | Deployed |

Each service owns its own `Dockerfile` and is built and pushed by the
`ci-services.yml` GitHub Actions workflow on changes to its path. OpenAPI specs
are the source of truth for request/response shapes:
- `cove-api`: `services/cove-api/api/openapi.yaml`
- `cove-image`: `services/cove-image/api/openapi.yaml`
- `cove-catalog`: `services/cove-catalog/api/openapi.yaml`
- `cove-directory`: `services/cove-directory/api/openapi.yaml`
- `cove-user`: `services/cove-user/api/openapi.yaml`

See [docs/BACKEND_INFRASTRUCTURE.md](../docs/BACKEND_INFRASTRUCTURE.md) for the
full service map, naming convention, and migration phases.
