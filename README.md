# k8s-multi-tenant-platform-reference

A reference implementation of the multi-tenant EKS platform pattern — genericized for public use. It demonstrates the architectural pattern, not a specific deployment.

## The problem

A platform team running dozens of application teams on Kubernetes typically ends up with one of two failure modes:
- **Cluster-per-team sprawl**: every team gets its own cluster "for isolation," and the platform team ends up managing 50+ clusters, each under-utilized, each needing its own upgrades, patching, and on-call.
- **One shared cluster, no isolation**: cheaper to run, but a noisy-neighbor or misconfigured team can take down everyone else, and there's no clean way to enforce per-team quotas or security boundaries.

## The pattern this repo demonstrates

Multi-tenant clusters with **namespace-level isolation, dynamic provisioning, and GitOps-driven deployment** — the same shape of solution that took a real cluster fleet from a large sprawl of single-tenant clusters down to a consolidated, multi-tenant footprint, cutting compute cost by cutting waste rather than cutting capability.

```
                    ┌─────────────────────────────────────────┐
                    │              Git (source of truth)        │
                    │   platform/ (this repo)   apps/ (per-team) │
                    └───────────────────┬─────────────────────┘
                                         │ GitOps sync
                                         ▼
   ┌───────────────────────────────────────────────────────────────┐
   │                         EKS Cluster                            │
   │  ┌───────────────┐  ┌──────────────────┐  ┌─────────────────┐ │
   │  │  Argo CD        │  │  Karpenter          │  │  Policy Layer     │ │
   │  │  (delivery      │  │  (dynamic node      │  │  (ResourceQuotas, │ │
   │  │   plane)        │  │   provisioning)     │  │   NetworkPolicies)│ │
   │  └───────────────┘  └──────────────────┘  └─────────────────┘ │
   │  ┌───────────────┐  ┌──────────────────┐  ┌─────────────────┐ │
   │  │  team-a         │  │  team-b            │  │  team-c           │ │
   │  │  namespace      │  │  namespace         │  │  namespace        │ │
   │  │  (quota-bound)  │  │  (quota-bound)     │  │  (quota-bound)    │ │
   │  └───────────────┘  └──────────────────┘  └─────────────────┘ │
   └───────────────────────────────────────────────────────────────┘
```

See [`docs/architecture.md`](docs/architecture.md) for the full breakdown by plane, and [`docs/adr/`](docs/adr/) for the reasoning behind each major decision.

## What's in this repo

```
k8s-multi-tenant-platform-reference/
├── docs/
│   ├── architecture.md          # Planes, components, and how they fit together
│   └── adr/                     # Architecture Decision Records
│       ├── 0001-karpenter-over-cluster-autoscaler.md
│       ├── 0002-namespace-multi-tenancy-over-cluster-per-team.md
│       └── 0003-gitops-delivery-over-manual-kubectl-apply.md
├── terraform/
│   ├── modules/
│   │   ├── eks-cluster/         # EKS control plane + node IAM
│   │   ├── karpenter/           # Karpenter controller + NodePool/EC2NodeClass
│   │   └── tenancy/             # Per-team namespace + quota + network policy
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── gitops/
    ├── argocd/
    │   ├── app-of-apps.yaml         # Root Argo CD Application
    │   └── applicationset-tenants.yaml  # Auto-generates one Application per team dir
    └── policies/
        └── resource-quota-template.yaml
```

## Results this pattern is designed to produce

These are the outcome categories the pattern targets, not a specific company's numbers:
- Meaningful compute cost reduction from bin-packing multiple teams onto shared, right-sized nodes instead of static per-team capacity
- Faster new-team onboarding — a new tenant is a namespace + a Git PR, not a new cluster
- Consistent security posture across teams via policy enforced at the platform layer, not per-team discipline

## Running it

```bash
cd terraform
terraform init
terraform plan -var="cluster_name=demo" -var="region=us-east-1"
```

This is reference infrastructure meant to be read and adapted, not applied as-is against a production AWS account.

## License

MIT
