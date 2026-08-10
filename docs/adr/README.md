# Decision log

The reasoning behind each structural decision in this repo, in the order the decisions were made.

| # | Decision | Status |
|---|---|---|
| [0001](0001-karpenter-over-cluster-autoscaler.md) | Karpenter over Cluster Autoscaler | Accepted |
| [0002](0002-namespace-multi-tenancy-over-cluster-per-team.md) | Namespace-level multi-tenancy over cluster-per-team | Accepted |
| [0003](0003-gitops-delivery-over-manual-kubectl-apply.md) | GitOps delivery over manual `kubectl apply` | Accepted |
| [0004](0004-secrets-management.md) | External Secrets Operator for secrets management | Accepted |
| [0005](0005-policy-admission-control.md) | Pod Security Admission plus Kyverno | Accepted |

## Conventions

Statuses are `Proposed`, `Accepted`, or `Superseded by ADR-NNNN`. Records aren't edited after acceptance: when an answer changes, a new record supersedes the old one, and the old one stays in the log. Every accepted record ends with **Revisit when**, the conditions under which it stops being the right answer.

These are the same conventions as my [architecture portfolio](https://github.com/anujg21/architecture-portfolio), which pools records across systems to show the method itself. This log is that method applied inside the repository the decisions belong to.
