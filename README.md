# Cove - Local Community Discovery
[![CI - iOS](https://github.com/danicajiao/cove/actions/workflows/ci-ios.yml/badge.svg)](https://github.com/danicajiao/cove/actions/workflows/ci-ios.yml)

<img width="1630" alt="Screenshot 2025-04-23 at 12 36 21 AM" src="https://github.com/user-attachments/assets/a6194687-e7ce-4ca4-a534-b6852527d8ad" />

## About

Cove helps people discover conscious businesses and quality producers near them: who makes or sells what they're looking for, and where to find it, ranked by verified trust rather than ad spend. Cove doesn't sell anything; visits and purchases happen in person. It's a passion project for exploring native iOS development, UX/UI design, mobile CI/CD, Firebase, and AI-assisted development workflows.

The project also serves as a testbed for agentic development: using AI agents to automate parts of the development process, such as implementing Figma designs directly into SwiftUI and orchestrating multi-step coding tasks from GitHub issues.

## Repository layout

This is a monorepo. Apps, services, and shared packages live under their respective top-level directories:

```
cove/
├── apps/                   # Client applications
│   └── ios/                # Swift / SwiftUI iOS app (this is what runs in Xcode)
├── services/               # Backend services
│   └── cove-api/           # Go gateway service (Phase 1)
├── packages/               # Shared schemas, design tokens (planned)
└── docs/                   # Cross-cutting product/architecture docs
```

## Tech Stack (iOS app)

| Layer | Technology |
|---|---|
| Platform | iOS 26+ |
| Language | Swift / SwiftUI |
| Architecture | MVVM |
| Backend | Firebase (Auth, Firestore, Cloud Storage) |
| Dependencies | Swift Package Manager |
| CI/CD | GitHub Actions + Fastlane |

## Getting Started

### Prerequisites

- **Xcode 26.4+** (required for iOS 26 SDK and objectVersion 100 project format)

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/danicajiao/cove.git
cd cove

# 2. Open the iOS project
open apps/ios/Cove.xcodeproj
```

Dependencies are managed via Swift Package Manager and resolve automatically when you open the project in Xcode.

### Firebase Configuration

The app requires a `GoogleService-Info.plist` to connect to Firebase. This file is not committed to the repository. Request access by opening an issue or contacting the project owner, then place it at:

```
apps/ios/Cove/Supporting Files/GoogleService-Info.plist
```

### Build and Run

Select a simulator or connected device in Xcode and press **⌘R**.

For CI/CD setup, see [CI/CD Workflows Documentation](docs/CI_CD_WORKFLOWS.md).

## iOS app structure

```
apps/ios/Cove/
├── Supporting Files/   # App entry point (CoveApp.swift), Info.plist
├── Models/             # Data models and global state (AppState, Bag, FavoritesStore)
├── View Models/        # Business logic and Firestore access
├── Views/              # SwiftUI views organized by feature
├── Components/         # Reusable UI components (ProductCardView, LikeButton, etc.)
├── Styles/             # Custom button styles and view modifiers
├── Enums/              # Shared enum types (ProductTypes)
├── Constants/          # Design token constants (Spacing.swift, Radius.swift)
└── Resources/          # Assets, fonts (Gazpacho, Lato), Rive animations
```

See [iOS App Architecture](docs/IOS_APP_ARCHITECTURE.md) for a detailed breakdown of how data flows through the app.

## Feature Status

- [x] Sign in with Google, Facebook, or email/password
- [x] Persistent login state via Firebase Auth
- [x] Product listings fetched in real-time from Firestore
  - [x] Coffee
  - [x] Music
  - [x] Apparel
  - [ ] Home, Beverages, Tea (planned)
- [x] Product detail view with type-specific tabs (Origin, Tracklist, Specifications)
- [x] Shopping bag with quantity management and similar product recommendations
- [x] Favorites — save products and view them in the Favorites tab
- [ ] Browse tab
- [ ] Search with filters
- [ ] Store/brand pages
- [ ] Checkout and stock checking
- [ ] Reviews and ratings
- [ ] Friend system
- [ ] Personalized recommendations

## Documentation

| Doc | Description |
|---|---|
| [Quick Start Guide](docs/QUICK_START.md) | Prerequisites, setup, and troubleshooting |
| [iOS App Architecture](docs/IOS_APP_ARCHITECTURE.md) | MVVM structure, data flows, Firebase model |
| [CI/CD Workflows](docs/CI_CD_WORKFLOWS.md) | GitHub Actions workflows, Fastlane lanes, versioning |
| [Secrets Setup](docs/SECRETS_SETUP.md) | Configuring GitHub secrets for CI/CD |
| [All Docs](docs/README.md) | Full documentation index |

## Contributing

### Branching

This project uses trunk-based development. Every branch is tied to a GitHub issue.

Format: `<label>/<REPO>-<issue-number>-<short-description>` when a GitHub issue exists, or `<label>/<short-description>` for off-cycle changes with no issue.

The `<REPO>` prefix is ALL CAPS and identifies the issue tracker — always `COVE` for this repo.

| Label | Use |
|---|---|
| `feature/` | New screens or user-facing functionality |
| `enhancement/` | Improvements to existing features |
| `bugfix/` | Bug fixes |
| `docs/` | Documentation-only changes |
| `chore/` | Refactoring, cleanup, config, tooling |

Examples: `feature/COVE-21-favorites-view`, `bugfix/COVE-3-fix-login-crash`, `docs/update-readme`

### Issue Labels

Every issue gets a **type** label and most get one or more **area** labels. Area labels drive which agent picks the issue up.

| Area label | Scope |
|---|---|
| `ios` | Any work on the iOS platform — views, view models, components, networking, repositories (everything under `apps/ios/`) |
| `backend` | Go services, APIs, data persistence (everything under `services/`) |
| `ui/ux` | Front-end design work — visual layouts or motion/animation. Marks that a design governs the work; an iOS screen or animation with a design is `ios` + `ui/ux` |
| `testing` | Unit, integration, or test-suite work |

The `swiftui-engineer` agent picks up any `ios` issue; when one also carries `ui/ux`, it matches the implementation to the design. The `ui/ux` label is design-tool-agnostic — there are no tool-specific labels (no `figma`, no `rive`); the specific design asset goes in the issue's Technical Notes. See `.claude/agents/github-project-planner.md` for the full taxonomy (type and meta labels).

### Pull Requests

PR titles or descriptions should include a closing keyword and the issue number so GitHub auto-closes the issue on merge:

```
Closes #21
```

This project spans two repos (`danicajiao/cove` and `danicajiao/homelab`). When referencing an issue or PR in the other repo, always use the fully qualified format so GitHub links it correctly:

```
danicajiao/homelab#28   ← referencing a homelab PR from cove
danicajiao/cove#234     ← referencing a cove issue from homelab
```

Note: `Closes owner/repo#N` does not auto-close cross-repo — GitHub only auto-closes within the same repo.

### CI

Every PR automatically runs SwiftFormat and SwiftLint checks. Main branch runs a full build and test suite via Fastlane.

### AI Agents

This project uses Claude Code agents to automate development tasks — implementing Figma designs as SwiftUI views, planning GitHub issues, and maintaining documentation. Each agent runs in an isolated git worktree so multiple agents can work simultaneously without conflicts. Every agent task produces a PR that goes through the same review and CI process as human contributions.

Agents are defined in `.claude/agents/`. See the individual agent files for their workflows and responsibilities.

## Roadmap

A simple roadmap for Cove can be found at https://github.com/users/danicajiao/projects/2.
