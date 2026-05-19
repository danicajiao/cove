# Backend Infrastructure

> **Status:** Phase 0 complete. The cluster is fully bootstrapped and running. The iOS app still uses Firebase directly — backend services come online in Phases 1–3 one at a time. Firebase Auth is kept throughout.

## Contents

- [Goals](#goals)
- [Architecture](#architecture)
- [Platform layer (installed, Phase 0)](#platform-layer-installed-phase-0)
- [Repo structure](#repo-structure)
- [Service naming](#service-naming)
- [Container images](#container-images)
- [Migration phases](#migration-phases)
- [Manifest conventions](#manifest-conventions)
- [K3s → GKE migration path](#k3s--gke-migration-path)
- [References](#references)

---

## Goals

- Remove reliance on Firebase for data and storage (Auth stays — it's the hardest to replace and provides the most value)
- Host compute on a personal K3s machine to eliminate backend costs during development
- GitOps everything — every infrastructure change is a PR, Argo CD reconciles from `main`
- Manifests written for K3s run on GKE unchanged if the cluster ever needs to move to the cloud

---

## Architecture

```
iOS App
    │
    │  Firebase Auth SDK (kept throughout all phases)
    │  Firebase ID Token in Authorization: Bearer header
    │
    ▼
api.coveapp.dev  (Cloudflare Tunnel — no open ports on the home machine)
    │
    ▼
cove-gateway  (K3s pod, cove-staging / cove-prod namespace)
    │  Validates Firebase ID Token via Firebase Admin SDK
    │  Routes to backend services by path prefix
    │
    ├── /images/*  ──►  cove-image   (Phase 2)
    ├── /products/* ──►  cove-product (Phase 3)
    └── /users/*   ──►  cove-user    (Phase 3)
```

Firebase Auth is the only GCP dependency in the request path. There is no GCP API Gateway, no Cloud Run, no Cloud SQL.

---

## Platform layer (installed, Phase 0)

The cluster runs on a single-node K3s machine (AMD Ryzen 9600X, 64 GB RAM). Every operator is managed by Argo CD watching the [`homelab`](https://github.com/danicajiao/homelab) repo.

| Operator | Purpose | Namespace |
|---|---|---|
| Argo CD | GitOps reconciler — watches `homelab` repo, applies changes | `argocd` |
| External Secrets Operator | Syncs GCP Secret Manager → K8s Secrets | `external-secrets` |
| CloudNativePG (CNPG) | Manages Postgres `Cluster` CRDs | `cnpg-system` |
| Garage | S3-compatible object storage (`cove-media`, `postgres-backups`, `loki` buckets) | `garage` |
| kube-prometheus-stack | Prometheus + Grafana + Alertmanager | `monitoring` |
| Loki + Alloy | Log aggregation (Alloy tails pod logs → Loki, 14d retention) | `monitoring` |
| Cloudflare Tunnel | Exposes `api.coveapp.dev` → cluster without open ports | `cloudflare-tunnel` |

### Secrets

All real secret values live in **GCP Secret Manager**, split across two projects:

| Project | Secrets for |
|---|---|
| `cove-6a685` | Cove workloads — Garage `cove-media` credentials, service API keys |
| `homelab-495921` | Homelab infra — Grafana admin password, Cloudflare Tunnel credentials, Loki Garage credentials |

**Consumer-owns rule:** a secret lives in the GCP project of whatever workload consumes it. The ESO `ClusterSecretStore` for each project (`gcp-cove`, `gcp-homelab`) bridges GCP SM to K8s Secrets via `ExternalSecret` manifests in the relevant namespace.

---

## Repo structure

All buildable units live in this repo (`danicajiao/cove`). Deployment manifests live in a separate repo (`danicajiao/homelab`) that Argo CD watches.

```
danicajiao/cove                 ← all source code and docs
│
├── apps/
│   ├── ios/                    ← Swift / SwiftUI iOS app
│   ├── gateway/                ← cove-gateway service (Phase 1)
│   ├── image/                  ← cove-image service (Phase 2)
│   ├── product/                ← cove-product service (Phase 3)
│   └── user/                   ← cove-user service (Phase 3)
│
├── packages/                   ← shared code (API schema, types — as needed)
└── docs/

danicajiao/homelab              ← cluster infra (GitOps source for Argo CD)
│
├── infra/                      ← platform operators (one directory per operator)
│   ├── argocd/
│   ├── external-secrets/
│   ├── cnpg/
│   ├── garage/
│   ├── kube-prometheus-stack/
│   ├── loki/
│   ├── alloy/
│   └── cloudflare-tunnel/
│
├── apps/cove/                  ← Cove K8s manifests
│   ├── base/                   ← shared Deployments, Services, etc.
│   └── overlays/
│       ├── staging/            ← cove-staging namespace, staging image tags
│       └── prod/               ← cove-prod namespace, prod image tags
│
└── argocd/                     ← Argo CD Application manifests (app-of-apps)
```

### Build approach

Each service is built independently — no unified build tool required at this scale. The pattern:

- **Each service has its own `Dockerfile`** at `apps/<service>/Dockerfile`
- **GitHub Actions** builds and pushes each service's image on changes to its path (path filters prevent rebuilding unrelated services)
- **iOS** keeps its existing Fastlane CI lane
- **A root `Makefile`** provides convenience targets for local use:

```makefile
build-gateway:
    docker build -t cove-gateway apps/gateway/

build-all:
    docker build -t cove-gateway  apps/gateway/
    docker build -t cove-image    apps/image/
    docker build -t cove-product  apps/product/
    docker build -t cove-user     apps/user/
```

This avoids the significant setup cost of a polyglot build system (Bazel, etc.) while keeping the door open — if build times become a problem as the repo grows, the groundwork is already in place to adopt one.

The key property a unified build system would buy is incremental builds (only rebuild what changed) and a single CI invocation across all languages. GitHub Actions path filters give you the former cheaply; the latter can be added later.

---

## Service naming

Services drop the `-svc` suffix. The pod, K8s Service, and image name are all the same:

| Service | What it does | Phase |
|---|---|---|
| `cove-gateway` | BFF — validates Firebase token, routes to backend services | Phase 1 |
| `cove-image` | Image upload, resizing, CDN delivery via Garage | Phase 2 |
| `cove-product` | Product catalog, categories, search | Phase 3 |
| `cove-user` | User profiles, follows, producer accounts | Phase 3 |

In Kubernetes, each service runs as a `Deployment` in `cove-staging` or `cove-prod`, with a matching `Service` of the same name.

---

## Container images

Images are stored in Google Artifact Registry under the `cove-6a685` project:

```
us-central1-docker.pkg.dev/cove/services/cove-gateway:sha-abc1234
us-central1-docker.pkg.dev/cove/services/cove-image:sha-abc1234
us-central1-docker.pkg.dev/cove/services/cove-product:sha-abc1234
us-central1-docker.pkg.dev/cove/services/cove-user:sha-abc1234
```

Tags use the Git commit SHA (not `latest`) so every deployed version is traceable. The staging overlay pins the `sha-*` tag from the most recent CI build; the prod overlay promotes the same tag after staging validation.

---

## Migration phases

Each phase is independently shippable. The iOS app is updated incrementally — it never calls a service that isn't deployed.

### Phase 0 — Foundations ✅ complete

- K3s cluster running with Argo CD, ESO, CNPG, Garage, kube-prometheus-stack, Loki, Alloy, Cloudflare Tunnel
- `api.coveapp.dev` resolves to a placeholder response
- `cove-staging` and `cove-prod` namespaces exist, Argo CD overlays wired up
- iOS app still calls Firebase directly — no behavior change

### Phase 1 — Gateway

- Deploy `cove-gateway` to `cove-staging`
- iOS `APIClient` sends Firebase ID Token on all requests
- Gateway validates token, returns placeholder responses for all routes
- iOS app routes all backend calls through `APIClient` (Firestore/Storage still called directly for data)
- Smoke test: authenticated request to `api.coveapp.dev/health` returns 200

### Phase 2 — Image service

- Deploy `cove-image` to `cove-staging`
- Handles image uploads, resizing, and delivery from Garage `cove-media` bucket
- iOS app calls `api.coveapp.dev/images/*` instead of Firebase Storage
- Firebase Storage retired for new uploads

### Phase 3 — Data services

- Provision a single CNPG `Cluster` (`cove-db`) hosting the `cove` database with three schemas: `product`, `vendor`, and `user`. The `vendor` schema is pre-positioned for a future `cove-vendor` service — no service owns it in Phase 3; `cove-product` and `cove-user` get read-only + FK reference grants.
- Deploy `cove-product` and `cove-user` to `cove-staging`
- Postgres replaces Firestore for all structured data; cross-schema foreign keys preserve referential integrity for user-centric features (favorites, follows)
- iOS app calls `api.coveapp.dev/products/*` and `api.coveapp.dev/users/*`
- Firestore retired

### Phase 4 (planned) — Vendor service

Not yet planned in detail; tracked separately. Scope:

- Build `cove-vendor` at `apps/vendor/`
- Vendor onboarding flow (multi-step, business verification)
- Vendor profile management
- Vendor dashboard API (separate iOS/web surface for producers)
- Take ownership of the `vendor` schema via a permissions flip — no schema migration, no data move; `cove-product` keeps SELECT for catalog reads

---

## Manifest conventions

Follow these in every service manifest:

- **Always set resource requests and limits** — required for Prometheus to track resource usage; also required by GKE Autopilot if the cluster ever migrates
- **Externalize all config** via `ConfigMap` and `Secret` — no hardcoded endpoints or credentials in images
- **Use Kustomize overlays** for environment differences (image tag, replica count, resource limits)
- **Never hardcode namespace** in base manifests — Kustomize overlays set `namespace:` at the overlay level
- **One Deployment per service** — no sidecars except where explicitly justified (e.g., a metrics exporter)

---

## K3s → GKE migration path

K3s uses the same Kubernetes API as GKE — manifests written today run on GKE unchanged. If the cluster ever needs to move:

1. Images are already in Google Artifact Registry — no changes
2. Provision a GKE cluster
3. Apply existing Kustomize configs with a new `overlays/gke/` overlay
4. Update Cloudflare Tunnel to point at the GKE cluster's internal Service
5. Decommission K3s

---

## References

- [Postgres Primer](POSTGRES_PRIMER.md) — indexes, JSONB, full-text search, ltree
- [Marketplace Architecture](MARKETPLACE_ARCHITECTURE.md) — data layer design
- [Category & Product Architecture](CATEGORY_AND_PRODUCT_ARCHITECTURE.md) — category hierarchy and filtering
- [App Architecture](APP_ARCHITECTURE.md) — current iOS app structure and Firebase usage
