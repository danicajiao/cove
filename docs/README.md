# Cove Documentation

Welcome to the documentation for the Cove iOS app.

## 📖 Documentation Structure

### Getting Started
- **[Quick Start Guide](QUICK_START.md)** - Get the project building locally
  - Prerequisites and dependencies
  - Firebase configuration
  - Build and run instructions

### App
- **[Design System](DESIGN_SYSTEM.md)** - Color tokens, typography, spacing, radius, shadow, and Figma↔Swift component mapping
- **[App Architecture](APP_ARCHITECTURE.md)** - How the app is structured and how data flows
  - MVVM pattern and ViewModels
  - Authentication and navigation
  - Product type system
  - Firebase data model and Firestore queries

### CI/CD
- **[CI/CD Workflows](CI_CD_WORKFLOWS.md)** - All workflows, versioning, and deployment
  - Workflow overview and architecture
  - TestFlight and App Store deployment
  - Local Fastlane usage and troubleshooting

- **[Secrets Setup Guide](SECRETS_SETUP.md)** - Configuring GitHub secrets for CI/CD
  - Code signing certificates and provisioning profiles
  - App Store Connect API key
  - GitHub Personal Access Token

### Architecture (Planned)
- **[Backend Infrastructure](BACKEND_INFRASTRUCTURE.md)** - Planned infrastructure: K3s, GCP API Gateway, Cloudflare Tunnel, migration phases
- **[Marketplace Architecture](MARKETPLACE_ARCHITECTURE.md)** - Planned data layer: hybrid SQL, NoSQL & GraphQL backend
- **[Category & Product Architecture](CATEGORY_AND_PRODUCT_ARCHITECTURE.md)** - Planned category hierarchy and filtering system

### Feature Planning
- **[LLM Integration Ideas](LLM_INTEGRATION_IDEAS.md)** - Potential ways to incorporate LLMs as production features

### Technical Reference
- **[Fastlane Configuration](../fastlane/README.md)** - Fastlane lanes and local usage

## 🎯 Which Document Should I Read?

### I want to run this project locally
→ Start with [Quick Start Guide](QUICK_START.md)

### I want to understand how the app works
→ Read [App Architecture](APP_ARCHITECTURE.md)

### I'm implementing UI and need color/font/spacing tokens
→ Read [Design System](DESIGN_SYSTEM.md)

### I need to configure CI/CD secrets
→ Follow [Secrets Setup Guide](SECRETS_SETUP.md)

### I want to understand the CI/CD workflows
→ Read [CI/CD Workflows](CI_CD_WORKFLOWS.md)

### Something in CI/CD isn't working
→ See Troubleshooting section in [CI/CD Workflows](CI_CD_WORKFLOWS.md)

### I want to understand the planned backend infrastructure
→ Read [Backend Infrastructure](BACKEND_INFRASTRUCTURE.md)

### I want to understand the planned data layer
→ Read [Marketplace Architecture](MARKETPLACE_ARCHITECTURE.md)

---

**Last Updated**: March 2026
