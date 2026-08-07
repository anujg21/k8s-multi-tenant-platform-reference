# Prior Art

Where this pattern's choices line up with official guidance, and how other teams have described the same problem.

## Namespace-based ("soft") multi-tenancy

Matches [Kubernetes' own multi-tenancy docs](https://kubernetes.io/docs/concepts/security/multi-tenancy/): shared cluster, some mutual trust assumed, versus "hard" multi-tenancy (dedicated clusters, sandboxed runtimes) for adversarial tenants. Same controls the docs recommend — namespaces, RBAC, quota, network policy, PSA — plus API Priority and Fairness, which this repo doesn't configure yet (see [production-readiness.md](production-readiness.md)).

This is the same trade-off [ADR-0002](adr/0002-namespace-multi-tenancy-over-cluster-per-team.md) already names: namespace isolation is weaker than cluster isolation against a malicious co-tenant, accepted because tenants are internal teams under a shared security baseline.

## Cluster consolidation, in the wild

The "30+ clusters, each drifted, each under capacity" story this README opens with isn't a strawman — it's a documented pattern. See ["How We Stopped Running 30 Clusters"](https://medium.com/@surbhi19/kubernetes-multi-tenancy-in-2026-how-we-stopped-running-30-clusters-and-finally-got-it-right-92beabd60556) and [Northflank's 2026 multi-tenancy guide](https://northflank.com/blog/kubernetes-multi-tenancy).

## Karpenter

[ADR-0001](adr/0001-karpenter-over-cluster-autoscaler.md)'s reasoning holds up against the [official disruption docs](https://karpenter.sh/docs/concepts/disruption/). One gap closed this pass: an explicit disruption budget instead of the implicit default (see [security-review.md](security-review.md)).

Worth knowing: teams with real stateful workloads typically run two `NodePool`s — aggressive for stateless, conservative for stateful — instead of one pool for everything. This repo's single pool is fine for a demo, not for production.

## EKS Access Entries over `aws-auth`

`authentication_mode = "API"` matches [current AWS guidance](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html) — API-managed, auditable via CloudTrail, no risk of a YAML typo locking everyone out. Never called out in an ADR despite being a deliberate, correct choice — noted here so it doesn't look accidental.

## Beyond namespaces

ADR-0002 already named `vcluster` as the middle ground between namespace and cluster isolation, deferred for complexity. Two more options worth knowing: [Capsule](https://www.cncf.io/blog/2025/09/23/solving-kubernetes-multi-tenancy-challenges-with-vcluster/) (CNCF, groups namespaces under one tenant with inherited policy) and the archived Kubernetes Hierarchical Namespace Controller. Neither strengthens isolation between tenants — both just let a tenant span more than one namespace.
