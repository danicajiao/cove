# Cove - A Curated Marketplace
[![CI - Main](https://github.com/danicajiao/cove-ios/actions/workflows/ci-main.yml/badge.svg)](https://github.com/danicajiao/cove-ios/actions/workflows/ci-main.yml)

<img width="1630" alt="Screenshot 2025-04-23 at 12 36 21 AM" src="https://github.com/user-attachments/assets/a6194687-e7ce-4ca4-a534-b6852527d8ad" />

## About

Cove is a curated marketplace of conscious businesses and quality producers — a passion project for exploring native iOS development, UX/UI design, mobile CI/CD, Firebase, and AI-assisted development workflows.

The project also serves as a testbed for agentic development: using AI agents to automate parts of the development process, such as implementing Figma designs directly into SwiftUI and orchestrating multi-step coding tasks from GitHub issues.

## Tech Stack

| Layer | Technology |
|---|---|
| Platform | iOS 18+ |
| Language | Swift / SwiftUI |
| Architecture | MVVM |
| Backend | Firebase (Auth, Firestore, Cloud Storage) |
| Dependencies | Swift Package Manager |
| CI/CD | GitHub Actions + Fastlane |

## Getting Started

### Prerequisites

- **Xcode 16+** (required for iOS 18 SDK)

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/danicajiao/cove-ios.git
cd cove-ios

# 2. Open the project
open Cove.xcodeproj
```

Dependencies are managed via Swift Package Manager and resolve automatically when you open the project in Xcode.

### Firebase Configuration

The app requires a `GoogleService-Info.plist` to connect to Firebase. This file is not committed to the repository. Request access by opening an issue or contacting the project owner, then place it at:

```
Cove/Supporting Files/GoogleService-Info.plist
```

### Build and Run

Select a simulator or connected device in Xcode and press **⌘R**.

For CI/CD setup, see [CI/CD Workflows Documentation](docs/CI_CD_WORKFLOWS.md).

## Project Structure

```
Cove/
├── Supporting Files/   # App entry point (CoveApp.swift), Info.plist
├── Models/             # Data models and global state (AppState, Bag, FavoritesStore)
├── View Models/        # Business logic and Firestore access
├── Views/              # SwiftUI views organized by feature
├── Components/         # Reusable UI components (ProductCardView, LikeButton, etc.)
├── Styles/             # Custom button styles and view modifiers
├── Enums/              # Shared enum types (ProductTypes)
└── Resources/          # Assets, fonts (Gazpacho, Lato), Rive animations
```

See [App Architecture](docs/APP_ARCHITECTURE.md) for a detailed breakdown of how data flows through the app.

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
| [App Architecture](docs/APP_ARCHITECTURE.md) | MVVM structure, data flows, Firebase model |
| [CI/CD Workflows](docs/CI_CD_WORKFLOWS.md) | GitHub Actions workflows, Fastlane lanes, versioning |
| [Secrets Setup](docs/SECRETS_SETUP.md) | Configuring GitHub secrets for CI/CD |
| [All Docs](docs/README.md) | Full documentation index |

## Contributing

### Branching

This project uses trunk-based development. Every branch is tied to a GitHub issue.

Format: `<label>/<issue-id>-<description-in-kebab-case>`

| Label | Use |
|---|---|
| `feature/` | New screens or user-facing functionality |
| `enhancement/` | Improvements to existing features |
| `bug/` | Bug fixes |
| `docs/` | Documentation-only changes |
| `chore/` | Maintenance, config, tooling |

Examples: `feature/21-favorites-view`, `bug/3-fix-login-crash`, `docs/update-readme`

### Pull Requests

PR titles or descriptions should include a closing keyword and the issue number so GitHub auto-closes the issue on merge:

```
Closes #21
```

### CI

Every PR automatically runs SwiftFormat and SwiftLint checks. Main branch runs a full build and test suite via Fastlane.

### AI Agents

This project uses Claude Code agents to automate development tasks — implementing Figma designs as SwiftUI views, planning GitHub issues, and maintaining documentation. Each agent runs in an isolated git worktree so multiple agents can work simultaneously without conflicts. Every agent task produces a PR that goes through the same review and CI process as human contributions.

Agents are defined in `.claude/agents/`. See the individual agent files for their workflows and responsibilities.

## Roadmap

A simple roadmap for Cove can be found at https://github.com/users/danicajiao/projects/2.
