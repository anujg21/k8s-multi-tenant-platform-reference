# ADR-0002: Namespace-level multi-tenancy over cluster-per-team

**Status:** Accepted

## Context

Starting point: every application team runs on its own dedicated cluster, nominally for isolation. As team count grows, that's a large fleet of clusters, each with its own control-plane cost, upgrade cadence, add-ons, and on-call surface — most running well under capacity.

The real question: does each team need cluster-level isolation, or does namespace-level isolation meet the actual security and reliability bar at a fraction of the cost?

## Decision

Shared, multi-tenant clusters with namespace-level isolation (RBAC, `ResourceQuota`, default-deny `NetworkPolicy`) as the default. Dedicated clusters stay reserved for the subset of workloads with a hard regulatory or blast-radius requirement namespace isolation genuinely can't meet.

## Reasoning

- Most teams needed protection from noisy neighbors and accidental cross-team access — which namespace quotas, RBAC, and network policy handle directly — not protection from an actively adversarial co-tenant, which is what cluster isolation is really built for.
- Operational cost scales with cluster count, not team count. Every cluster is another control plane to patch, another add-on set to keep in lockstep, another blast radius for platform misconfiguration.
- Dedicated clusters are sized for peak and mostly sit below it. A shared cluster lets Karpenter ([ADR-0001](0001-karpenter-over-cluster-autoscaler.md)) bin-pack across teams' complementary usage.
- A new team on a shared cluster is a namespace, a quota, and an Argo CD `Application` — one PR. A new dedicated cluster is a Terraform apply, an add-on rollout, and a new line in every runbook.

## Trade-offs accepted

- Weaker than cluster isolation against a genuinely malicious co-tenant with kernel-level exploits — accepted because tenants are internal teams under a shared security baseline, not untrusted third parties.
- A cluster-wide incident now has a bigger blast radius than cluster-per-team would. Mitigated with staged platform rollouts and splitting clusters by environment/blast-radius tier, not one cluster for the whole org.
- Noisy-neighbor risk is bounded, not eliminated — `ResourceQuota`/`LimitRange` need active maintenance per namespace, not a set-and-forget default.

## Alternatives considered

- **Cluster-per-team (status quo)** — rejected: overhead compounds as team count grows.
- **Virtual clusters (vcluster)** — middle ground, each team gets what looks like its own control plane on shared infrastructure. Not adopted this iteration — more architectural complexity than the isolation gain justifies for this tenant population, worth revisiting if a subset of teams needs stronger isolation later.
- **Cluster-per-team with heavy automation** — cuts manual toil, not the underlying multiplier of control-plane count and utilization waste. Doesn't fix the root cause.

## Revisit when

A tenant arrives whose threat model includes a hostile co-tenant, or whose regulator demands isolation a shared kernel can't provide. That workload takes the dedicated-cluster exception this decision already reserves; if such workloads become the majority, the default itself is wrong. Also revisit when one shared cluster grows into too large a blast radius, whether that shows up as API server strain, IP exhaustion, or upgrade windows that no longer fit. The vcluster middle ground noted above is worth a second look at that point.
