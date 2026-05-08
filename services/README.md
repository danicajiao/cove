# Services

Backend services. Each subdirectory is an independently deployable service.

Planned:

| Service | Purpose |
|---|---|
| `products/` | Product catalog, inventory |
| `users/` | User accounts, profiles, auth |

Services share types and schemas via `../packages/api-schema/`. Each service owns its own deploy pipeline.
