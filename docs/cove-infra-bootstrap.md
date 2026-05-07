# cove-infra Bootstrap Guide

> **Status:** Phase 0 deliverable. Walks through creating the `cove-infra` repository and laying down the initial Kustomize + Argo CD skeleton that every subsequent infra sub-issue assumes exists.

`cove-infra` is the GitOps source of truth for the Cove K3s cluster. Argo CD watches this repo and reconciles cluster state against it. Every operator, service, and config that runs in the cluster lands here.

This doc is the runbook for the **first** push to that repo. Operator installs (Argo CD itself, External Secrets Operator, CloudNativePG, MinIO, kube-prometheus-stack, Loki) are tracked separately and add their own manifests under this skeleton in later sub-issues.

---

## Prerequisites

- `gh` CLI authenticated as `danicajiao`
- `git` configured locally
- A K3s cluster reachable via `kubectl` (only needed for the Argo CD bootstrap step at the end — not for creating the repo)

---

## Step 1 — Create the repository

```bash
gh repo create danicajiao/cove-infra \
    --private \
    --description "GitOps source of truth for the Cove K3s cluster (Argo CD + Kustomize)" \
    --clone

cd cove-infra
```

This creates an empty private repo and clones it locally.

---

## Step 2 — Lay down the directory structure

```bash
mkdir -p base overlays/staging overlays/prod argocd
```

Final layout after this guide:

```
cove-infra/
├── README.md
├── .gitignore
├── base/
│   └── kustomization.yaml          # Lists shared, env-agnostic resources
├── overlays/
│   ├── staging/
│   │   └── kustomization.yaml      # Binds base to cove-staging namespace
│   └── prod/
│       └── kustomization.yaml      # Binds base to cove-prod namespace
└── argocd/
    ├── staging-app.yaml            # Argo CD Application → overlays/staging
    └── prod-app.yaml               # Argo CD Application → overlays/prod
```

### Why this shape

- **`base/`** holds manifests that are identical across environments — operator installs, CRDs, shared `ConfigMap`s. Each operator sub-issue (#214–#217) adds its YAML here and registers it in `base/kustomization.yaml`.
- **`overlays/<env>/`** customizes `base/` per environment. The only difference between staging and prod for now is the target namespace (`cove-staging` vs `cove-prod`); env-specific image tags, replica counts, or resource limits go here too as we grow.
- **`argocd/`** holds Argo CD `Application` manifests — one per environment. These are what you `kubectl apply` once after Argo CD is installed (sub-issue #210). After that, Argo CD watches the repo and reconciles automatically.

---

## Step 3 — Create the skeleton files

### `README.md`

```markdown
# cove-infra

GitOps source of truth for the Cove K3s cluster. Argo CD watches this repo and
reconciles the cluster against it.

## Layout

- `base/` — env-agnostic manifests (operators, CRDs, shared resources)
- `overlays/staging/` — staging overlay; binds to the `cove-staging` namespace
- `overlays/prod/` — prod overlay; binds to the `cove-prod` namespace
- `argocd/` — Argo CD `Application` manifests, applied once during cluster
  bootstrap to point Argo CD at this repo

See `cove-ios/docs/cove-infra-bootstrap.md` for the bootstrap runbook and
`cove-ios/docs/BACKEND_INFRASTRUCTURE.md` for the overall infra plan.

## Conventions

- All resources go through `base/` first; overlays only patch what differs
  between environments.
- Operator manifests (Argo CD, ESO, CNPG, MinIO, etc.) live under
  `base/operators/<name>/` and are listed in `base/kustomization.yaml`.
- Secrets are never committed in plaintext — use `ExternalSecret` resources
  that reference GCP Secret Manager.
```

### `.gitignore`

```
.DS_Store
*.swp
*.bak
.idea/
.vscode/
```

### `base/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Shared, environment-agnostic resources.
# Operator sub-issues add entries here as they're installed.
resources: []
```

The empty `resources` list is intentional — operator sub-issues append to it.

### `overlays/staging/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: cove-staging

resources:
    - ../../base
```

### `overlays/prod/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: cove-prod

resources:
    - ../../base
```

The `namespace:` field is the namespace binding model — every resource pulled
in via `resources:` is rewritten to live in `cove-staging` or `cove-prod`
depending on which overlay is applied. Resources that must live in a specific
namespace (e.g., operator controllers in `kube-system`) override this with an
explicit `metadata.namespace` in their own manifest.

### `argocd/staging-app.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
    name: cove-staging
    namespace: argocd
spec:
    project: default
    source:
        repoURL: https://github.com/danicajiao/cove-infra.git
        targetRevision: main
        path: overlays/staging
    destination:
        server: https://kubernetes.default.svc
        namespace: cove-staging
    syncPolicy:
        automated:
            prune: true
            selfHeal: true
        syncOptions:
            - CreateNamespace=true
```

### `argocd/prod-app.yaml`

Same as `staging-app.yaml` with these substitutions:

- `metadata.name`: `cove-prod`
- `spec.source.path`: `overlays/prod`
- `spec.destination.namespace`: `cove-prod`

> Prod uses the same auto-sync policy for now since this is a solo project. If
> we ever want manual gating on prod deploys, drop the `automated:` block from
> `prod-app.yaml`.

---

## Step 4 — Commit and push

```bash
git add .
git commit -m "Initial cove-infra skeleton with Kustomize + Argo CD layout"
git branch -M main
git push -u origin main
```

The repo is now ready for operator sub-issues to layer manifests onto.

---

## Step 5 — Bootstrap Argo CD against this repo

This step happens **after** sub-issue #210 (install Argo CD). Tracked here only
so the chain is visible — do not run this until Argo CD is installed.

```bash
kubectl apply -f argocd/staging-app.yaml
kubectl apply -f argocd/prod-app.yaml
```

From this point on, every change merged to `cove-infra/main` is reconciled
into the cluster automatically.

---

## What gets added by later sub-issues

| Sub-issue | Adds |
|---|---|
| #210 | Argo CD install manifests (manual install, then bootstrap step above) |
| #214 | External Secrets Operator under `base/operators/external-secrets/` |
| #215 | CloudNativePG operator under `base/operators/cnpg/` |
| #216 | MinIO under `base/operators/minio/` |
| #217 | kube-prometheus-stack and Loki under `base/operators/observability/` |
| #218 | Cloudflare Tunnel manifests |
| #219 | Namespace `Namespace` resources for `cove-staging` and `cove-prod` (if not already created via `CreateNamespace=true` on the Application) |

Each of those sub-issues opens its own PR against `cove-infra` (not `cove-ios`).
