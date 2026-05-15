# Cove Infrastructure Layout in Homelab

> Cove's backend services and the platform operators they depend on live in the [`homelab`](https://github.com/danicajiao/homelab) repo, alongside other K3s tenants. This doc is a pointer; runbooks and operational details live in `homelab/docs/`.

## Why homelab and not a dedicated repo

Originally planned as a separate `cove-infra` repo, then consolidated into homelab because:

- **One cluster → one GitOps source of truth.** Splitting GitOps for the same cluster across two repos creates coordination headaches around shared platform components.
- **Shared platform operators deduplicate across tenants.** Argo CD, External Secrets Operator, CloudNativePG, MinIO, the observability stack — all installed once, used by every tenant.
- **Argo CD bootstrap is a one-time, cluster-wide concern**, not a per-product one.

If Cove ever migrates off the home K3s cluster (e.g., to GKE), the `apps/cove/` subtree and the cove-relevant pieces of `infra/` carve out cleanly into a new repo. No design choice today blocks that path.

## Where Cove sits in homelab

```
homelab/
├── apps/
│   ├── gaming/
│   │   └── minecraft/                    # separate tenant, not Cove
│   └── cove/
│       ├── base/                         # cove-gateway, cove-product, cove-user, cove-image (added Phases 1-3)
│       └── overlays/
│           ├── staging/                  # → cove-staging namespace
│           └── prod/                     # → cove-prod namespace
├── infra/                                # cluster-wide platform operators
│   ├── argocd/
│   ├── external-secrets/
│   ├── cnpg/
│   ├── minio/
│   ├── kube-prometheus-stack/
│   ├── loki/
│   └── cloudflare-tunnel/
└── argocd/                               # Argo CD Application manifests (app-of-apps roots)
    ├── root.yaml
    ├── argocd-self.yaml
    ├── infra-app.yaml
    ├── apps-cove-staging.yaml
    └── apps-cove-prod.yaml
```

`apps/` is per-tenant per-environment. `infra/` is cluster-singleton platform components. `argocd/` is the app-of-apps tree Argo CD reconciles against.

## Service repos (still planned, separate)

Each backend service is its own repo with its own CI pipeline. The repo builds container images and pushes to GAR; `homelab` declares how those images run.

| Repo | Phase | Sub-issue |
|---|---|---|
| `cove-gateway` | 1 | [#229](https://github.com/danicajiao/cove-ios/issues/229) |
| `cove-image` | 2 | [#238](https://github.com/danicajiao/cove-ios/issues/238) |
| `cove-product` | 3 | [#250](https://github.com/danicajiao/cove-ios/issues/250) |
| `cove-user` | 3 | [#250](https://github.com/danicajiao/cove-ios/issues/250) |

These repos do not exist yet — created when each phase begins.

## Runbooks

Operational docs live in [`homelab/docs/`](https://github.com/danicajiao/homelab/tree/main/docs):

| Runbook | Covers |
|---|---|
| `argocd-install.md` | Argo CD bootstrap, app-of-apps pattern, day-2 ops |
| (more added per Phase 0 sub-issue) | |

## See also

- [Backend Infrastructure](BACKEND_INFRASTRUCTURE.md) — overall stack and migration phases
- [App Architecture](APP_ARCHITECTURE.md) — current iOS app structure
