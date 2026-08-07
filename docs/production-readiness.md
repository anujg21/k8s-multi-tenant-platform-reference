# Production Readiness

This repo is a pattern reference, not a deployable platform. This page tracks what's missing before a real team could run on it, so the gaps are explicit instead of quietly deferred.

## Required before adoption

| Gap | Why it matters | Direction |
|---|---|---|
| Secrets management | GitOps + no secrets path = plaintext in Git | External Secrets Operator, namespace-scoped `SecretStore`. [ADR-0004](adr/0004-secrets-management.md) |
| Policy beyond RBAC/quota | RBAC controls who, not what. PSA (done) covers pod security only — no image checks, no org policy | Kyverno on top of PSA. [ADR-0005](adr/0005-policy-admission-control.md) |
| Ingress / DNS / TLS | `architecture.md`'s own diagram shows an ingress controller — none exists. Every tenant app is `ClusterIP`-only today | AWS Load Balancer Controller or ingress-nginx on the static node group, plus cert-manager and External DNS |

## Everything else

- **Observability** — nothing collects metrics or logs. No way to tell whose workload is causing a problem.
- **Cost visibility** — Karpenter cuts aggregate waste, but nothing attributes cost back to a tenant. [OpenCost](https://github.com/opencost/opencost) reads existing namespace labels, no code changes needed.
- **Backup / DR** — no PV or object backup. [Velero](https://velero.io), scoped per namespace, fits the self-service model here.
- **Image supply chain** — no registry allowlist, no signature checks. The sample deployment used to pull `:latest`; now pinned, but nothing enforces that platform-wide. Natural extension of the Kyverno layer above.
- **Control-plane fairness at scale** — see [security-review.md](security-review.md). Doesn't matter with 3 demo teams; matters at "dozens of teams."
- **Dedicated Karpenter node IAM role** — currently reuses the static node group's role. Fine today, since both node types need the same baseline AWS permissions; only matters if that ever needs to diverge.
- **Hierarchical namespaces** — not needed at this scale. Worth a look ([Capsule](https://github.com/projectcapsule/capsule)) if a tenant ever needs more than one namespace.
