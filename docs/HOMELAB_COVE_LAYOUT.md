# Cove Infrastructure Layout in Homelab

> Cove's backend services and the platform operators they depend on live in the [`homelab`](https://github.com/danicajiao/homelab) repo, alongside other K3s tenants. This doc is a pointer; runbooks and operational details live in `homelab/docs/`.

## Why homelab and not a dedicated repo

Originally planned as a separate `cove-infra` repo, then consolidated into homelab because:

- **One cluster → one GitOps source of truth.** Splitting GitOps for the same cluster across two repos creates coordination headaches around shared platform components.
- **Shared platform operators deduplicate across tenants.** Argo CD, External Secrets Operator, CloudNativePG, Garage, the observability stack — all installed once, used by every tenant.
- **Argo CD bootstrap is a one-time, cluster-wide concern**, not a per-product one.

If Cove ever migrates off the home K3s cluster (e.g., to GKE), the `apps/cove/` subtree and the cove-relevant pieces of `infra/` carve out cleanly into a new repo. No design choice today blocks that path.

## Where Cove sits in homelab

```
homelab/
├── apps/
│   ├── gaming/
│   │   └── minecraft/                    # separate tenant, not Cove
│   └── cove/
│       ├── base/                         # cove-api (P1), cove-media + imgproxy (P2), cove-catalog + cove-directory + cove-user (P3), cove-db (CNPG cluster); each in its own subdir
│       └── overlays/
│           ├── staging/                  # → cove-staging namespace
│           └── prod/                     # → cove-prod namespace
├── infra/                                # cluster-wide platform operators
│   ├── argocd/
│   ├── external-secrets/
│   ├── cnpg/
│   ├── garage/
│   ├── kube-prometheus-stack/
│   ├── loki/
│   ├── alloy/
│   └── cloudflare-tunnel/
└── argocd/                               # Argo CD Application manifests (app-of-apps roots)
    ├── root.yaml                         # applied directly; not listed in kustomization.yaml
    ├── kustomization.yaml                # lists every child Application below
    ├── argocd-self.yaml
    ├── cert-manager.yaml
    ├── external-secrets.yaml
    ├── cnpg.yaml
    ├── cnpg-barman-plugin.yaml
    ├── garage.yaml
    ├── kube-prometheus-stack.yaml
    ├── loki.yaml
    ├── alloy.yaml
    ├── cloudflare-tunnel.yaml
    ├── minecraft.yaml
    ├── apps-cove-staging.yaml
    └── apps-cove-prod.yaml
```

`apps/` is per-tenant per-environment. `infra/` is cluster-singleton platform components. `argocd/` is the app-of-apps tree Argo CD reconciles against.

## Service source (in the cove monorepo)

Backend services live in the `danicajiao/cove` monorepo under `services/cove-<name>/`, **not** in separate repos. The `ci-services.yml` workflow builds each service's container image and pushes it to GAR; `homelab` declares how those images run.

| Service | Path in `danicajiao/cove` | Phase | Deployment | Implementation issue |
|---|---|---|---|---|
| `cove-api` | `services/cove-api/` | 1 | staging + prod | [danicajiao/cove#229](https://github.com/danicajiao/cove/issues/229) |
| `cove-media` | `services/cove-media/` | 2 | staging + prod | [danicajiao/cove#238](https://github.com/danicajiao/cove/issues/238), renamed in [danicajiao/cove#414](https://github.com/danicajiao/cove/issues/414) |
| `imgproxy` | upstream image; HMAC signing helper in `packages/imgproxy/` | 2 | staging + prod | — |
| `cove-catalog` | `services/cove-catalog/` | 3 | staging + prod | [danicajiao/cove#321](https://github.com/danicajiao/cove/issues/321), split in [danicajiao/cove#413](https://github.com/danicajiao/cove/issues/413) |
| `cove-directory` | `services/cove-directory/` | 3 | staging + prod | [danicajiao/cove#413](https://github.com/danicajiao/cove/issues/413) |
| `cove-user` | `services/cove-user/` | 3 | staging + prod | [danicajiao/cove#322](https://github.com/danicajiao/cove/issues/322) |

`cove-api` shipped in Phase 1; `cove-media` (then `cove-image`) and `imgproxy` in Phase 2; `cove-user` and `cove-item` in Phase 3. Epic [danicajiao/cove#393](https://github.com/danicajiao/cove/issues/393) split `cove-item` into `cove-catalog` and `cove-directory`, renamed `cove-image` to `cove-media`, and cut both environments over in one homelab PR ([danicajiao/homelab#73](https://github.com/danicajiao/homelab/pull/73)). The `cove-api` and `cove-media` issue links predate the monorepo decision and reference the original separate-repo planning tickets.

Each service has a matching CNPG role bootstrapped in `apps/cove/base/cove-db/cluster.yaml` (`cove_catalog`, `cove_directory`, `cove_user`). Services still connect as the `app` user. Both overlays must pin an `images:` tag for every service, or cove CI's bump job fails.

## Runbooks

Operational docs live in [`homelab/docs/`](https://github.com/danicajiao/homelab/tree/main/docs):

| Runbook | Covers |
|---|---|
| `argocd-install.md` | Argo CD bootstrap, app-of-apps pattern, day-2 ops |
| `cnpg-install.md` | CloudNativePG operator install and cluster provisioning |
| `external-secrets-install.md` | External Secrets Operator setup and secret stores |
| `garage-install.md` | Garage S3-compatible object storage install |
| `kube-prometheus-stack-install.md` | Prometheus + Grafana monitoring stack |
| `loki-install.md` | Loki log aggregation install |
| `node-setup.md` | K3s node provisioning and prerequisites |
| `commands.md` | Common cluster operations cheat sheet |

## See also

- [Backend Infrastructure](BACKEND_INFRASTRUCTURE.md) — overall stack and migration phases
- [iOS App Architecture](IOS_APP_ARCHITECTURE.md) — current iOS app structure
