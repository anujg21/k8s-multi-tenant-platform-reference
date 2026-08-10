# ADR-0001: Karpenter over Cluster Autoscaler

**Status:** Accepted

## Context

The platform needs to provision compute dynamically for tenant teams with different, unpredictable resource shapes. Two mainstream options on EKS:

- **Cluster Autoscaler** — scales predefined node groups (fixed instance types, fixed AZs) up and down.
- **Karpenter** — provisions nodes directly against EC2, choosing instance type, size, and AZ per the pending pod's actual requirements.

## Decision

Karpenter as the primary provisioner, with a minimal static node group kept only for cluster-critical add-ons that can't depend on Karpenter's own scheduling loop.

## Reasoning

- Node groups don't fit heterogeneous multi-tenant load — a memory-heavy batch job next to a CPU-light API pod means maintaining many partially-idle groups, the exact waste this platform exists to eliminate.
- Karpenter bin-packs per-pod against live demand; Cluster Autoscaler's bin-packing is a byproduct of node-group sizes chosen in advance.
- Onboarding a new team shouldn't require a Terraform PR for a new node group. Karpenter's `NodePool`/`EC2NodeClass` CRDs handle a new workload shape without one.
- Most of the realized compute savings comes from eliminating the padding fixed node groups need to stay safe, not from any single "smaller nodes" change.

## Trade-offs accepted

- Karpenter moves faster than the long-stable Cluster Autoscaler; upgrade discipline matters more.
- Debugging "why didn't my pod get a node" shifts from node-group min/max to `NodePool` requirements and EC2 capacity — a different mental model for on-call, worth a short runbook.
- A static node group is still required for anything that must survive Karpenter's own controller being briefly down.

## Alternatives considered

- **Cluster Autoscaler only** — rejected: node-group proliferation under heterogeneous multi-tenant load.
- **Fargate for everything** — rejected: several tenant workloads need DaemonSets, host networking, or GPU access Fargate doesn't support. Still an option for specific stateless workloads layered on top.

## Revisit when

The workload mix settles into a few stable, predictable shapes. Fixed node groups would then do the job with one less fast-moving controller to patch, and the bin-packing advantage mostly disappears. Also revisit if EKS Auto Mode's managed Karpenter covers this platform's `NodePool` needs: running the controller yourself stops earning its keep once AWS runs it for you.
