# ADR-0002: Namespace-level multi-tenancy instead of cluster-per-team

**Status:** Accepted

## Context

The platform starts from a state where many application teams each run on their own dedicated cluster, nominally for isolation. As the number of teams grows, this produces a large fleet of clusters, each requiring its own control-plane cost, upgrade cadence, add-on management, and on-call surface — most of them running well under capacity.

The core question: does each team actually need cluster-level isolation, or does namespace-level isolation meet the real security and reliability requirement at a fraction of the operational cost?

## Decision

Consolidate teams onto shared, multi-tenant clusters using namespace-level isolation (RBAC scoping, `ResourceQuota`, default-deny `NetworkPolicy`) as the default. Reserve dedicated clusters for the specific subset of workloads with a hard regulatory or blast-radius requirement that namespace isolation genuinely cannot satisfy.

## Reasoning

- **Cluster-level isolation was solving a problem most teams didn't actually have.** The majority of internal application teams needed protection from noisy neighbors and accidental cross-team access — both of which namespace-scoped quotas, RBAC, and network policy address directly — not protection from an actively adversarial co-tenant, which is the threat model cluster isolation is really built for.
- **Operational cost scales with cluster count, not with team count.** Every additional cluster is another control plane to patch, another set of add-ons (CNI, ingress, observability agents, security scanners) to keep in version lockstep, and another blast radius for platform-level misconfiguration. Consolidating clusters collapses this multiplier directly.
- **Utilization.** Dedicated clusters are sized for each team's peak, most of the time sitting well below it. A shared multi-tenant cluster lets Karpenter (ADR-0001) bin-pack across teams' complementary usage patterns.
- **Faster onboarding.** A new team joining a shared cluster is a namespace, a quota, and an Argo CD `Application` entry — reviewable in a single PR. A new dedicated cluster is a Terraform apply, an add-on rollout, and a new entry in every platform-wide operational runbook.

## Trade-offs accepted

- Namespace isolation is weaker than cluster isolation against a genuinely malicious co-tenant with kernel/node-level exploits; the platform accepts this because the tenant population is internal application teams under a shared security baseline, not untrusted third parties.
- A cluster-wide incident (e.g. a control-plane issue, or a bad platform-level policy rollout) now has a larger blast radius across teams than it would with cluster-per-team. This is mitigated with staged rollouts of platform-level changes and multiple clusters split by environment/blast-radius tier, rather than one cluster for the whole organization.
- Noisy-neighbor risk isn't eliminated, only bounded — `ResourceQuota` and `LimitRange` need to be actively maintained per namespace, not set once and forgotten.

## Alternatives considered

- **Status quo (cluster-per-team)** — rejected due to compounding operational overhead as team count grows.
- **Virtual clusters (vcluster or similar)** — offers a middle ground (each team gets what looks like their own control plane, backed by shared infrastructure). Not adopted in this iteration due to added architectural complexity relative to the isolation gain for this tenant population, but flagged as worth revisiting if a subset of teams needs stronger isolation without full cluster dedication.
- **Cluster-per-team with heavy automation** — reduces the *manual* overhead but not the fundamental multiplier of control-plane count, add-on version drift, and utilization waste; doesn't address the root cause.
