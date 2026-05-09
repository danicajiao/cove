# Cove — Claude Context

## Project Overview

Cove is a monorepo containing the Cove iOS app and (eventually) a web client, backend services, and shared packages. The iOS app uses SwiftUI with MVVM, Firebase (Auth, Firestore, Storage), Swift Package Manager, and targets iOS 26+.

**Repo layout:**

```
cove/
├── apps/
│   └── ios/                # Swift / SwiftUI iOS app — see apps/ios/Cove/
├── services/               # Backend services (planned)
├── packages/               # Shared code (api-schema, design-tokens — planned)
└── docs/                   # Cross-cutting product/architecture docs
```

**iOS-specific:**

- **Required Xcode version: 26.4+** — `objectVersion = 100` requires Xcode 26.4+. CI selects Xcode 26.4.1 via `DEVELOPER_DIR=/Applications/Xcode_26.4.1.app/Contents/Developer`.
- All iOS commands (`swiftformat`, `swiftlint`, `bundle exec fastlane ...`) must be run from `apps/ios/`.

See `docs/` for architecture details: `APP_ARCHITECTURE.md`, `QUICK_START.md`, `CI_CD_WORKFLOWS.md`.

---

## Branch Naming

Format: `<label>/<issue-id>-<description-in-kebab-case>`

| Label | Use |
|---|---|
| `feature/` | New screens or user-facing functionality |
| `enhancement/` | Improvements to existing features |
| `bug/` | Bug fixes |
| `docs/` | Documentation-only changes |
| `chore/` | Maintenance, config, tooling |

Examples:
- `feature/137-profile-view-model`
- `enhancement/66-improve-tab-navigation`
- `bug/3-fix-login-crash`
- `docs/update-readme`

---

## Commit Messages

Imperative mood, sentence case.

```
Add ProfileViewModel with Firebase Auth user data
```

- Start with a verb: `Add`, `Update`, `Fix`, `Refactor`, `Remove`, `Build`
- Keep the subject line under 72 characters
- PR merge commits include the PR number: `Build ProfileRowView (#145)`

---

## iOS Code Conventions

### Architecture — MVVM

- **Views** (`apps/ios/Cove/Views/`, `apps/ios/Cove/Components/`): SwiftUI only, no business logic
- **ViewModels** (`apps/ios/Cove/View Models/`): `ObservableObject`, marked `@MainActor`, one per major view
- **Models** (`apps/ios/Cove/Models/`): Data structures and global state (e.g. `AppState`, `Bag`)
- **Enums** (`apps/ios/Cove/Enums/`): Shared enum types (`ProductTypes`); note that `AuthState`, `AuthMethod`, and `Path` are currently defined in `Models/AppState.swift`
- **Styles** (`apps/ios/Cove/Styles/`): Custom `PrimitiveButtonStyle` implementations

### Naming

- Types: `PascalCase` — `HomeView`, `ProductDetailViewModel`, `CoffeeProduct`
- Properties/variables: `camelCase` — `viewModel`, `productId`, `averageColor`
- Files: match the primary type — `HomeView.swift` contains `struct HomeView: View`

### View Patterns

```swift
// Top-level screen: owns the ViewModel
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var appState: AppState
}

// Child component: receives ViewModel from parent
struct ProfileHeaderView: View {
    @ObservedObject var viewModel: ProfileViewModel
}

// Complex views: extract content into a private struct
private struct ProductDetailContent: View { ... }
```

- Use `@StateObject` when the view owns and instantiates the ViewModel
- Use `@ObservedObject` when passing a ViewModel down to a child component
- Use `@EnvironmentObject` for global state (`AppState`, `Bag`, `FavoritesStore`)
- Extract large `body` blocks into private structs or computed properties
- Include `#Preview` at the bottom of every view file
- Wrap async Firebase calls in `Task { try await viewModel.fetch...() }` inside `.onAppear`

### Colors & Fonts

Always use semantic tokens — never hardcode hex values or use system colors. See `docs/DESIGN_SYSTEM.md` for the full token reference including all color groups, type scale, spacing, and radius values.

The four rules to remember:
- `Backgrounds.*` — canvas layers only (outermost `.background()` of a screen)
- `Fills.*` — component surfaces and non-text foreground elements (icons, shapes)
- `Text.*` — `.foregroundStyle()` on SwiftUI `Text` views only
- `Strokes.*` — `.stroke()` and `.border()` on shapes and overlays

### Formatting

- Indentation: 4 spaces
- Max line width: 150 characters (SwiftFormat), 200 warning / 250 error (SwiftLint)
- No semicolons
- From `apps/ios/`, run `swiftformat .` before committing (config in `apps/ios/.swiftformat`)
- From `apps/ios/`, run `swiftlint` before committing and resolve any errors

---

## iOS File Organization

```
apps/ios/Cove/
├── Supporting Files/   # App entry point
├── Models/             # Data + global state
├── View Models/        # Business logic
├── Views/              # Screens (subfolders group related views, e.g. Profile/)
├── Components/         # Reusable UI components
├── Styles/             # Button styles and view modifiers
├── Enums/              # Shared enum types
├── Constants/          # Design token constants (Spacing.swift, Radius.swift)
└── Resources/          # Assets, fonts, Rive animations
```

Group new views in a subfolder when they belong to the same feature screen (e.g., `Views/Profile/`).

---

## Agent Workflows

Claude agents run in isolated git worktrees — each agent gets its own directory on disk and its own branch, allowing multiple agents to work on the codebase simultaneously without interfering with each other.

### Full Pipeline

```
github-project-planner
  └── creates epic + sub-issues on GitHub
        └── (optional) creates integration branch: feature/<epic-id>-<description>
              └── sub-issue is picked up by an agent
                    └── harness spins up a worktree: branch claude/<name>, isolated directory
                          └── agent renames branch: feature/<issue-id>-<desc>
                                └── agent implements, runs swiftformat + swiftlint from the affected app dir, commits, pushes
                                      └── PR created targeting integration branch (or main) with "Closes #<issue-id>"
                                            └── PRs merged into integration branch → tested
                                                  └── integration branch PR merged to main → epic closed
```

Multiple sub-issues can be in-flight simultaneously, each in its own worktree, each on its own branch. They never touch each other's files.

### Integration branches

Integration branches are optional and used for **cross-cutting epics** that span multiple apps/services (e.g. iOS + a backend service in the same epic). Single-area epics can target `main` directly.

- Integration branch name follows the convention: `feature/<epic-id>-<description>`
- The integration branch is created from `main` at the time the epic is planned
- A PR from the integration branch to `main` is opened once all sub-issues are merged and tested

### GitHub operations: use `gh`, not the MCP

All GitHub interactions in this project — issue reads/writes, PR creation, sub-issue linking, label lookups, GraphQL mutations — must go through the `gh` CLI. **Never call a `mcp__plugin_github_github__*` tool.**

Why: the GitHub MCP doesn't propagate into agent worktrees. Even when the parent Claude Code session has the plugin authenticated, agents spawned in worktrees see only the OAuth-stub tools (`authenticate` / `complete_authentication`) and silently fall back to `gh`, which produces inconsistent behavior across runs. Making `gh` the explicit and only path removes that ambiguity. `gh` is preauthenticated machine-wide, works in every worktree, and survives session restarts.

This rule applies to every agent **and** to the main session. If the MCP propagation gets fixed in a future Claude Code release, revisit — but until then, `gh` is the path.

### When you are running as an agent in a worktree

- You are already on an isolated branch (initially named `claude/<worktree-name>`) — do not run `git checkout -b`
- Rename the branch to follow the naming convention before pushing: `git branch -m <label>/<issue-id>-<description>`
- For iOS work: `cd apps/ios` before running `swiftformat .` and `swiftlint`
- Commit and push your changes to that branch
- Open a PR targeting the epic's integration branch (provided in your task prompt) or `main` if there is no epic
- Include `Closes #<issue-id>` in the PR description

### Issue-to-agent routing

| Sub-issue labels | Handled by |
|---|---|
| `ui/ux` + `figma` | `swiftui-engineer` |
| `docs` | `documentation-maintainer` |
| planning / epics | `github-project-planner` |
