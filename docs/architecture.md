# Architecture

This platform is organized into three planes. Splitting responsibility this way keeps the concerns — "who's allowed to do what," "how does capacity show up," and "how does code get to running pods" — independently reasoned about and independently testable, instead of tangled into one big cluster config.

## 1. Delivery Plane — Argo CD

Nothing reaches the cluster by a human running `kubectl apply`. Every change flows through Git:

- **Root Application (`app-of-apps.yaml`)** — bootstraps the platform layer itself (Karpenter, policy controllers, the ApplicationSet controller).
- **`ApplicationSet` (tenants)** — watches an `apps/teams/*` directory structure in the deployment repo and generates one Argo CD `Application` per team automatically. Onboarding a new team is "add a directory," not "provision a new pipeline."

This is what makes namespace-per-team tenancy operationally cheap: the delivery mechanism scales by adding Git directories, not by adding platform-team toil.

## 2. Compute Plane — Karpenter

Karpenter watches for unschedulable pods and provisions right-sized EC2 capacity on demand, then consolidates or terminates nodes as load drops. Compared to a fixed node-group model:

- No pre-provisioned "team capacity" sitting idle
- Bin-packing across tenants happens automatically at the node level
- Spot/on-demand mix and instance-type selection are policy, not manual node-group math

This is the mechanism behind most of the compute-cost reduction in a multi-tenant consolidation: waste comes from **static capacity per team**, not from workloads themselves.

## 3. Tenancy & Policy Plane — Namespaces, Quotas, Network Policies

Each team gets an isolated namespace, not an isolated cluster:

- **`ResourceQuota`** caps CPU/memory/object counts per namespace so one team's spike can't starve another's
- **`NetworkPolicy`** default-denies cross-namespace traffic in both directions — ingress *and* egress — unless explicitly allowed
- **Pod Security Admission** (`baseline`, audited toward `restricted`) blocks privileged pods, host-network access, and hostPath mounts — so a single pod can't break out onto the shared node and undo the isolation above
- **RBAC** scopes each team's service accounts and CI credentials to their own namespace only

This is the trade-off documented in [ADR-0002](adr/0002-namespace-multi-tenancy-over-cluster-per-team.md): namespace isolation is weaker than cluster isolation, but it's strong enough for internal application teams under a shared security baseline, and it collapses cluster-management overhead by an order of magnitude.

## How a change flows through the system

1. A platform engineer or team opens a PR against the deployment repo (Terraform for infra, or a manifest under `apps/teams/<team>/` for an app).
2. On merge, Argo CD detects drift between Git and the live cluster and syncs.
3. If the change requires new capacity, Karpenter observes unschedulable pods and provisions nodes within seconds.
4. Policy controllers (quota, network policy) enforce boundaries regardless of what the team deployed — the platform doesn't trust the app to self-limit.

## What this pattern deliberately does *not* solve

Being explicit about limits is part of the architecture, not an afterthought:

- **Not a substitute for cluster isolation where it's actually required** (e.g. regulatory workloads needing hard tenancy boundaries) — for those, cluster-per-tenant is still the right call, and this pattern should be layered on top of, not instead of, that decision.
- **Not a cost model by itself** — Karpenter reduces waste, it doesn't replace FinOps visibility into what's being spent and why. See [`docs/production-readiness.md`](production-readiness.md) for the recommended path (OpenCost) to attribute cost back to tenants.
- **Assumes a baseline of platform trust** — namespace isolation relies on every tenant workload not being actively adversarial. This is standard for internal enterprise multi-tenancy; it is not the right model for hosting untrusted third-party workloads.

See [`docs/prior-art.md`](prior-art.md) for how this compares to official guidance, [`docs/security-review.md`](security-review.md) for gaps within this model, and [`docs/production-readiness.md`](production-readiness.md) for what's referenced here but not yet built.
