# Fastlane Setup for Cove iOS

This directory contains Fastlane configuration for automating iOS app deployment.

## Installation

1. Install Ruby dependencies:
   ```bash
   bundle install
   ```

2. Install CocoaPods:
   ```bash
   pod install
   ```

## Available Lanes

### Build and Test

```bash
# Build the app for testing (no code signing)
bundle exec fastlane build

# Run unit tests
bundle exec fastlane test

# Run SwiftLint (if configured)
bundle exec fastlane lint
```

### Deployment

```bash
# Deploy to TestFlight
bundle exec fastlane beta

# Submit to App Store
# Note: Set version with version parameter
bundle exec fastlane release version:1.1.0
```

## Configuration

The Fastfile is configured for the Cove app with:
- Workspace: `Cove.xcworkspace`
- Scheme: `Cove`
- Bundle ID: `com.danicajiao.cove`

## Environment Variables

For deployment lanes, you'll need:
- `PROVISIONING_PROFILE_SPECIFIER`: Name of your provisioning profile

## CI/CD Integration

These lanes are integrated with GitHub Actions workflows:
- `cd-testflight.yml` - Uses `fastlane beta` to deploy to TestFlight
- `cd-appstore.yml` - Uses `fastlane release` to submit to App Store
- `ci-main.yml` - Uses `fastlane build` and `fastlane test` on every push to main

**Note:** The workflows use Fastlane for all iOS automation, providing:
- Consistent build and deployment process
- Automatic build number management with TestFlight synchronization
- Single tool for local development and CI/CD

See `docs/CI_CD_WORKFLOWS.md` for complete documentation.
