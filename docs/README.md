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
- **[App Architecture](IOS_APP_ARCHITECTURE.md)** - How the app is structured and how data flows
  - MVVM pattern and ViewModels
  - Authentication and navigation
  - Repository abstraction layer (CoveAPI implementations)
  - Firebase data model (historical; Firestore retired in Phase 3)

### CI/CD
- **[CI/CD Workflows](CI_CD_WORKFLOWS.md)** - All workflows, versioning, and deployment
  - Workflow overview and architecture
  - TestFlight and App Store deployment
  - Backend service CI (build, push to GAR, open homelab PR)
  - OpenAPI spec linting
  - Local Fastlane usage and troubleshooting

- **[Secrets Setup Guide](SECRETS_SETUP.md)** - Configuring GitHub secrets for CI/CD
  - Code signing certificates and provisioning profiles
  - App Store Connect API key
  - GitHub Personal Access Token

### Backend Architecture
- **[Backend Infrastructure](BACKEND_INFRASTRUCTURE.md)** - K3s cluster, the `cove-api` gateway, Cloudflare Tunnel, and migration phases (Phases 0–3 complete)
- **[Marketplace Architecture](MARKETPLACE_ARCHITECTURE.md)** - The canonical data model: producer/place/item entities, the trust signal system, composite scoring, geospatial discovery, schemas, and the discovery query
- **[Homelab Layout for Cove](HOMELAB_COVE_LAYOUT.md)** - Where Cove's backend services and platform operators live in the [`homelab`](https://github.com/danicajiao/homelab) repo

### Backend Reference
- **[Postgres Primer](POSTGRES_PRIMER.md)** - Schemas, indexes, EXPLAIN ANALYZE, transactions, JSONB, full-text search, and ltree — the concepts Cove's backend depends on
- **[Media Architecture](MEDIA_ARCHITECTURE.md)** - Image storage in Garage, on-the-fly transformation via imgproxy, the variant catalog, producer upload normalization, signed-URL auth model, and Cloudflare caching
- **[Database Migrations](DATABASE_MIGRATIONS.md)** - How to run golang-migrate against staging and production, dirty-state recovery, per-service migration tables, and superuser boundary rules
- **[Category Taxonomy](CATEGORY_TAXONOMY.md)** - The full v1 category tree (252 nodes across 10 top-level categories), design principles for tree nodes vs attributes, and the add/remove runbook

### Feature Planning
- **[LLM Integration Ideas](LLM_INTEGRATION_IDEAS.md)** - Potential ways to incorporate LLMs as production features

### Technical Reference
- **[Fastlane Configuration](../apps/ios/fastlane/README.md)** - Fastlane lanes and local usage

## 🎯 Which Document Should I Read?

### I want to run this project locally
→ Start with [Quick Start Guide](QUICK_START.md)

### I want to understand how the app works
→ Read [App Architecture](IOS_APP_ARCHITECTURE.md)

### I'm implementing UI and need color/font/spacing tokens
→ Read [Design System](DESIGN_SYSTEM.md)

### I need to configure CI/CD secrets
→ Follow [Secrets Setup Guide](SECRETS_SETUP.md)

### I want to understand the CI/CD workflows
→ Read [CI/CD Workflows](CI_CD_WORKFLOWS.md)

### Something in CI/CD isn't working
→ See Troubleshooting section in [CI/CD Workflows](CI_CD_WORKFLOWS.md)

### I want to understand the backend infrastructure
→ Read [Backend Infrastructure](BACKEND_INFRASTRUCTURE.md)

### I want to understand the data layer
→ Read [Marketplace Architecture](MARKETPLACE_ARCHITECTURE.md)

### I'm working on schema or backend service work
→ Read [Marketplace Architecture](MARKETPLACE_ARCHITECTURE.md) for the data model, then [Postgres Primer](POSTGRES_PRIMER.md) for Postgres mechanics

### I'm working on image uploads, serving, or anything imgproxy-related
→ Read [Media Architecture](MEDIA_ARCHITECTURE.md)

### I need to run or troubleshoot a database migration
→ Read [Database Migrations](DATABASE_MIGRATIONS.md)

### I want to understand or extend the category taxonomy
→ Read [Category Taxonomy](CATEGORY_TAXONOMY.md)

---

**Last Updated**: June 2026
