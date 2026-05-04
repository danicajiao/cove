# Cove iOS — Claude Context

## Project Overview

Cove is an iOS app built with SwiftUI following MVVM architecture. It uses Firebase (Auth, Firestore, Storage) for backend, CocoaPods for dependency management, and targets iOS 18+.

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

## Code Conventions

### Architecture — MVVM

- **Views** (`Views/`, `Components/`): SwiftUI only, no business logic
- **ViewModels** (`View Models/`): `ObservableObject`, marked `@MainActor`, one per major view
- **Models** (`Models/`): Data structures and global state (e.g. `AppState`, `Bag`)
- **Enums** (`Enums/`): Shared enum types (`ProductTypes`); note that `AuthState`, `AuthMethod`, and `Path` are currently defined in `Models/AppState.swift`
- **Styles** (`Styles/`): Custom `PrimitiveButtonStyle` implementations

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

Always use semantic tokens — never hardcode hex values or use system colors. The full token reference is in `docs/DESIGN_SYSTEM.md`.

**Three color groups, each with a distinct role:**

```swift
// Backgrounds — canvas layers only (top-level view backgrounds)
Color.Colors.Backgrounds.primary       // off-white warm canvas
Color.Colors.Backgrounds.secondary     // white secondary canvas

// Fills — component surfaces (buttons, cards, sheets, overlays)
Color.Colors.Fills.primary             // dark brown — primary button fill
Color.Colors.Fills.inverse             // white — card/input field surface

// Text — foreground text colors only (use on SwiftUI Text views)
Color.Colors.Text.primary              // dark brown
Color.Colors.Text.tertiary             // charcoal 60% — muted/secondary labels

// Other
Color.Colors.Strokes.primary           // dark brown border
Color.Colors.Brand.accent              // amber — interactive accent
```

**Fonts:**

```swift
Font.custom("Gazpacho-Black", size: 25)   // headings
Font.custom("Lato-Bold", size: 16)         // subheadings / emphasis
Font.custom("Lato-Regular", size: 14)      // body
```

**Spacing and radius — always use named constants, never raw values:**

```swift
.padding(.horizontal, Spacing.xl)     // 20pt
.padding(.vertical, Spacing.lg)       // 16pt
VStack(spacing: Spacing.md) { ... }   // 12pt
.cornerRadius(Radius.lg)              // 10pt — cards, sheets
.cornerRadius(Radius.md)              // 8pt — buttons, rows
```

### Formatting

- Indentation: 4 spaces
- Max line width: 150 characters (SwiftFormat), 200 warning / 250 error (SwiftLint)
- No semicolons
- Run `swiftformat .` before committing (config in `.swiftformat`)
- Run `swiftlint` before committing and resolve any errors

---

## File Organization

```
Cove/
├── Supporting Files/   # App entry point
├── Models/             # Data + global state
├── View Models/        # Business logic
├── Views/              # Screens (subfolders group related views, e.g. Profile/)
├── Components/         # Reusable UI components
├── Styles/             # Button styles and view modifiers
├── Enums/              # Shared enum types
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
        └── creates integration branch: feature/<epic-id>-<description>
              └── sub-issue is picked up by an agent
                    └── harness spins up a worktree: branch claude/<name>, isolated directory
                          └── agent renames branch: feature/<issue-id>-<desc>
                                └── agent implements, runs swiftformat + swiftlint, commits, pushes
                                      └── PR created targeting integration branch with "Closes #<issue-id>"
                                            └── PRs merged into integration branch → tested in main repo
                                                  └── integration branch PR merged to main → epic closed
```

Multiple sub-issues can be in-flight simultaneously, each in its own worktree, each on its own branch. They never touch each other's files.

### Integration branches

Every epic gets an integration branch created by `github-project-planner` at planning time. Sub-issue PRs target this branch instead of `main`, so all changes can be built and tested together before touching `main`.

- Integration branch name follows the same convention: `feature/<epic-id>-<description>`
- The integration branch is created from `main` at the time the epic is planned
- A PR from the integration branch to `main` is opened once all sub-issues are merged and tested

### When you are running as an agent in a worktree

- You are already on an isolated branch (initially named `claude/<worktree-name>`) — do not run `git checkout -b`
- Rename the branch to follow the naming convention before pushing: `git branch -m <label>/<issue-id>-<description>`
- Before committing, run `swiftformat .` then `swiftlint` and resolve any errors
- Commit and push your changes to that branch
- Open a PR targeting the epic's integration branch (provided in your task prompt) or `main` if there is no epic
- Include `Closes #<issue-id>` in the PR description

### Issue-to-agent routing

| Sub-issue labels | Handled by |
|---|---|
| `ui/ux` + `figma` | `figma-ui-implementer` |
| `docs` | `documentation-maintainer` |
| planning / epics | `github-project-planner` |
