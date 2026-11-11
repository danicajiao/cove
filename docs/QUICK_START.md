# Quick Start Guide

Get the Cove iOS app building and running on your local machine.

## Prerequisites

- **Xcode 26.4+** (required for iOS 26 SDK and objectVersion 100 project format)
- **Ruby + Bundler** — for Fastlane (optional, only needed for CI/CD lanes)

## Steps

### 1. Clone the repository

```bash
git clone https://github.com/danicajiao/cove.git
cd cove
```

### 2. Open the project

```bash
open apps/ios/Cove.xcodeproj
```

Dependencies are managed via Swift Package Manager. Xcode will resolve and download all packages automatically on first open.

### 3. Add `GoogleService-Info.plist`

The app requires a `GoogleService-Info.plist` file to connect to Firebase. This file contains API keys and project credentials and is **not committed to the repository**.

**Access is restricted to approved developers.** Request access by opening an issue or contacting the project owner.

Once you have the file, place it at:

```
apps/ios/Cove/Supporting Files/GoogleService-Info.plist
```

### 4. Build and run

Select a simulator or connected device in Xcode and press **⌘R**.

### 5. (Optional) Set up VS Code with Swift LSP

If you use VS Code, install the [Swift extension](https://marketplace.visualstudio.com/items?itemName=sswg.swift-lang) and then configure `xcode-build-server` so that SourceKit-LSP can understand the Xcode project. Without this, go-to-definition, hover docs, and symbol search won't work.

```bash
brew install xcode-build-server
cd apps/ios
xcode-build-server config -scheme Cove -project Cove.xcodeproj
```

This generates `apps/ios/buildServer.json` (gitignored — run it once per machine). Then open the project in VS Code using the workspace file:

```bash
open /path/to/Development/cove.code-workspace
```

> If you don't have a `cove.code-workspace` file yet, create one in your `Development` folder. See [the workspace file format](https://code.visualstudio.com/docs/editor/workspaces) — add `cove` and `cove/apps/ios` as separate folders so the Swift extension finds `buildServer.json`.

If LSP features stop working after a large refactor or a DerivedData wipe, rebuild in Xcode (⌘B) to refresh the index. Re-run `xcode-build-server config` only if you rename the Xcode scheme or move the project.

## Notes

- **Bundle ID:** `com.danicajiao.cove`
- **Minimum deployment target:** iOS 26.0
- Google Sign-In and Facebook Login are configured via `Info.plist` — no additional setup required beyond the `GoogleService-Info.plist`
- **Get started** on the Welcome screen signs in with Firebase anonymous auth (guest browsing), so the Firebase project must have the Anonymous sign-in provider enabled
- For CI/CD setup, see [CI/CD Workflows Documentation](CI_CD_WORKFLOWS.md)

## Troubleshooting

### SPM packages fail to resolve
→ In Xcode, go to **File → Packages → Resolve Package Versions**. If that doesn't help, try **File → Packages → Reset Package Caches**.

### Build fails with Firebase errors
→ Verify `GoogleService-Info.plist` is present at the correct path and added to the Xcode target

### Simulator shows blank screen or crashes on launch
→ Check that `GoogleService-Info.plist` is valid and matches the `cove-6a685` Firebase project

---

**Last Updated**: November 2026
