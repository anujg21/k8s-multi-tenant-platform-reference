# Security Review

Findings against the actual tenancy boundary (`terraform/modules/tenancy`, `terraform/modules/karpenter`, `terraform/modules/eks-cluster`), checked against current Kubernetes and AWS guidance.

Scored against this platform's own threat model ([ADR-0002](adr/0002-namespace-multi-tenancy-over-cluster-per-team.md)): tenants are internal teams, not adversaries. A misconfigured workload, not a kernel exploit.

## High — egress was wide open

The original `NetworkPolicy` pair only covered `Ingress`. A pod could reach anywhere outbound — other tenants, the open internet, or the node's IMDS endpoint (`169.254.169.254`), a common path to stealing the node's IAM credentials.

**Fixed:** added default-deny egress, plus explicit allows for DNS (`kube-system`, port 53) and same-namespace traffic. Teams add their own egress rules for anything external, same as the existing ingress pattern.

## High — no admission control

RBAC controls who can create objects, not what those objects contain. Nothing stopped a tenant's CI credential from deploying a privileged pod, `hostNetwork`, or a `hostPath` mount — a direct route off the namespace boundary onto the shared node.

**Fixed:** every namespace now sets Pod Security Admission labels (`enforce: baseline`, `audit`/`warn: restricted`). Baseline blocks the dangerous stuff without breaking normal workloads; restricted is warned so teams see what needs fixing before it's enforced. Configurable per tenant via `var.pod_security_enforce_level`.

PSA only covers the built-in pod-security surface — no image provenance, no custom org policy. See [ADR-0005](adr/0005-policy-admission-control.md).

## Medium — CI role can create bare pods

`kubernetes_role.ci_deployer` grants `create`/`update`/`patch` on `pods` directly. A normal `Deployment`-based CI flow doesn't need this — the Deployment controller creates pods, not the CI identity. A leaked CI credential can currently create a standalone pod that skips every guarantee a Deployment gives you.

**Not fixed** — some teams may genuinely rely on direct pod access for debugging or forced restarts. Recommend splitting into a narrow deploy role (`deployments`/`services`/`configmaps`) and a separate, sparingly-granted `pods`/`pods/log` read role.

## Medium — no control-plane rate limiting per tenant

Quota bounds what a tenant can run, not how hard they can hit the API server. A runaway watch loop or noisy CI pipeline can degrade the API server for everyone.

**Not fixed** — needs a cluster-wide [API Priority and Fairness](https://kubernetes.io/docs/concepts/cluster-administration/flow-control/) `FlowSchema` per tenant (stable since 1.29). Belongs in platform bootstrap, not the per-tenant module.

## Medium — no path for secrets

ADR-0003 already flagged this as unresolved. As it stands, the only way to get a secret into a tenant namespace through GitOps is committing it to Git in plaintext — the one thing GitOps is supposed to prevent.

**Not fixed** — needs an in-cluster controller, not a config tweak. See [ADR-0004](adr/0004-secrets-management.md).

## Low — no explicit Karpenter disruption budget

The shared `NodePool` relied on Karpenter's implicit default (`nodes: 10%`). One pool serving every tenant with no explicit cap risks a lopsided consolidation event hitting one tenant hard.

**Fixed:** added an explicit `disruption.budgets` block — same 10% default, now stated instead of assumed.

## Low — sample workload had no PodDisruptionBudget

Two replicas, no PDB, an aggressive consolidation policy — both replicas could get evicted close together.

**Fixed:** added a PDB (`minAvailable: 1`) and pinned the image tag (`nginx:1.27`, not `:latest`) — this is the manifest every team copies, so it should model good practice.

## Already right

- Karpenter's controller IAM policy: EC2 fleet actions only, `PassRole` scoped to one specific ARN, not `*`.
- Private-only EKS API endpoint, and EKS Access Entries instead of the legacy `aws-auth` ConfigMap (a well-known source of lockout incidents).
- The static critical-addons node group is tainted and Karpenter's controller tolerates it — the controller can never schedule itself onto a node it manages.

See [`production-readiness.md`](production-readiness.md) for anything above that needs more than a config change.
