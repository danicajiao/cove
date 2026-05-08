# Backend Infrastructure

> **Status:** Planned. The app currently uses Firebase exclusively. This document describes the target infrastructure as Cove migrates to a custom backend.

## Goals

- Remove reliance on Firebase for data and storage (Auth migrated last)
- Host compute on a personal machine to minimize cost
- Use Kubernetes (K3s) to build transferable skills — manifests are compatible with GKE if scale demands a cloud migration later
- Keep GCP API Gateway as the single cloud entry point

---

## Architecture

```
iOS App
    │
    │  Firebase Auth SDK (kept throughout migration)
    │  Firebase ID Token passed as Bearer on every request
    │
    ▼
GCP API Gateway                          ← cloud, managed, pay-per-request
    │
    │  Validates Firebase ID Token
    │  (Firebase Admin SDK, single auth check)
    │
    └── Cloudflare Tunnel ──► K3s on home machine
                                  ├── api-gateway pod (BFF / internal router)
                                  ├── product-service pod
                                  ├── user-service pod
                                  └── image-service pod
```

### Why each component

| Component | Role | Why |
|---|---|---|
| Firebase Auth | Identity, SSO (Google, Facebook) | Hardest to replace — kept last |
| GCP API Gateway | Public entry point, token validation | Managed, cheap, GCP learning |
| Cloudflare Tunnel | Secure home machine exposure | No open ports, no dynamic IP issues, free tier |
| K3s | Container orchestration on home machine | Full K8s API, low resource overhead, zero compute cost |
| Google Artifact Registry | Container image storage | Same registry when migrating to GKE later |

---

## Repo Structure (Polyrepo)

Each service lives in its own repo with independent versioning and release cycles. Infrastructure config is centralized.

```
cove-ios/           ← this repo (iOS app)
cove-gateway/       ← BFF, Firebase token validation, internal routing
cove-product-svc/   ← product catalog, favorites, search
cove-user-svc/      ← user profiles, social features
cove-image-svc/     ← image upload, processing, CDN delivery
cove-infra/         ← K8s manifests (Helm/Kustomize), Terraform, GCP config
```

`cove-infra` is the release coordination layer — it defines which version of each service is deployed to which environment. Cross-service dependency management lives here, not scattered across service repos.

---

## Migration Phases

Each phase is independently shippable. The iOS app is updated incrementally — it never calls a service that isn't ready.

### Phase 1 — Foundation

- Provision K3s on home machine
- Set up Cloudflare Tunnel
- Deploy GCP API Gateway
- iOS app sends Firebase ID Token to gateway on all requests
- Firebase Firestore and Storage still called directly by the app for now

### Phase 2 — Image Service

- Deploy `cove-image-svc` pod on K3s
- Handles image uploads, resizing, and CDN delivery
- iOS app calls `gateway/images` instead of Firebase Storage
- Firebase Storage retired for new uploads

### Phase 3 — Data Services

- Deploy `cove-product-svc` and `cove-user-svc` pods
- Postgres for structured data (products, vendors, users)
- iOS app calls `gateway/products` and `gateway/users`
- Firestore retired

### Phase 4 — Auth (when ready)

- Replace Firebase Auth with an OIDC provider
- Swap token validation in GCP API Gateway (one change, all services benefit)
- iOS app auth flow updated (sign-in screens, token handling)

---

## K3s to GKE Migration Path

K3s uses the same Kubernetes API as GKE — manifests written today run on GKE with minimal changes. The migration path when home machine compute is no longer sufficient:

1. Push images to Google Artifact Registry (already the registry from day one)
2. Provision GKE cluster
3. Apply existing Helm charts / Kustomize configs with environment overrides for GKE
4. Swap Cloudflare Tunnel endpoint for a GCP Load Balancer in GCP API Gateway config
5. Decommission K3s

---

## Manifest Conventions

To keep the K3s → GKE migration smooth, follow these conventions from the start:

- **Always set resource requests and limits** — required by GKE Autopilot, good practice everywhere
- **Externalize all config** via `ConfigMap` and `Secret` — no hardcoded endpoints or credentials in images
- **Use Helm charts or Kustomize** for environment-specific overrides (local vs staging vs prod)
- **Store all images in Google Artifact Registry** — `us-central1-docker.pkg.dev/cove/services/<name>`

---

## References

- [Marketplace Architecture](MARKETPLACE_ARCHITECTURE.md) — data layer design (SQL vs NoSQL, GraphQL)
- [App Architecture](APP_ARCHITECTURE.md) — current iOS app structure and Firebase usage
