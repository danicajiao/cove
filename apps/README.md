# Apps

User-facing applications. Each subdirectory is a deployable client.

| App | Stack | Status |
|---|---|---|
| `ios/` | Swift / SwiftUI, Firebase | Active |
| `web/` | TBD | Planned |

Each app owns its own build tooling and CI workflow. Cross-app concerns (shared types, design tokens) live in `../packages/`.
