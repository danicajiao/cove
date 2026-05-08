# Packages

Shared code consumed by multiple apps and services. The litmus test: if a file would otherwise be copy-pasted between two consumers, it belongs here.

Planned:

| Package | Purpose | Consumers |
|---|---|---|
| `api-schema/` | OpenAPI / GraphQL schema, source of truth for request/response shapes | apps + services |
| `design-tokens/` | Color, spacing, radius tokens as raw JSON; generated into Swift constants and CSS variables | `apps/ios`, `apps/web` |

Empty for now — packages should only be created when there's a real second consumer.
