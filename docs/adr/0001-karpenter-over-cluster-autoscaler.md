# ADR-0001: Use Karpenter instead of Cluster Autoscaler for dynamic provisioning

**Status:** Accepted

## Context

The platform needs to provision compute dynamically as multiple tenant teams schedule workloads with different, unpredictable resource shapes. Two mainstream options exist on EKS:

- **Cluster Autoscaler (CA)** — scales predefined node groups (fixed instance types, fixed AZs per group) up and down based on pending pods.
- **Karpenter** — provisions nodes directly against EC2, choosing instance type, size, and AZ per the actual pending pod's requirements, without being bound to predefined node groups.

## Decision

Use Karpenter as the primary provisioner, with a minimal static node group retained only for cluster-critical add-ons that must not depend on Karpenter's own scheduling.

## Reasoning

- **Node-group model doesn't fit multi-tenant, heterogeneous workloads.** With CA, supporting varied resource shapes (a memory-heavy batch job next to a CPU-light API pod) means maintaining many node groups, each partially idle. That's exactly the static-capacity waste the platform is trying to eliminate.
- **Bin-packing quality.** Karpenter provisions per-pod, choosing the tightest-fitting instance type from the allowed set, and consolidates by moving pods off underutilized nodes and terminating them. CA's bin-packing is a byproduct of node-group sizing choices made in advance, not of actual live demand.
- **Onboarding a new team shouldn't mean a Terraform PR for a new node group.** Karpenter's `NodePool`/`EC2NodeClass` CRDs let a new workload shape get scheduled without the platform team pre-defining a matching node group first.
- **Cost:** the combination of tighter bin-packing and easy spot/on-demand mixing per-`NodePool` is where most of the realized compute savings comes from — not from any single "make nodes smaller" change, but from eliminating the padding that fixed node groups require to stay safe.

## Trade-offs accepted

- Karpenter is a newer, faster-moving project than the long-stable Cluster Autoscaler; upgrade discipline matters more.
- Debugging "why didn't my pod get a node" shifts from "check node group min/max" to reasoning about `NodePool` requirements and EC2 quota/capacity — a different (not necessarily harder, but different) operational mental model for on-call engineers, requiring a short internal runbook.
- A minimal static node group is still required for workloads that must survive Karpenter/its controller being briefly unavailable (e.g. the Karpenter controller pod itself).

## Alternatives considered

- **Cluster Autoscaler only** — rejected due to node-group proliferation under multi-tenant heterogeneous load.
- **Fargate for all workloads** — removes node management entirely, but was rejected for this platform because several tenant workloads need DaemonSets, host networking, or GPU access that Fargate doesn't support; Fargate remains an option for specific stateless tenant workloads layered on top of this pattern, not a full replacement for it.
