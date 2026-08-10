# ADR-0003: GitOps delivery over manual `kubectl apply`

**Status:** Accepted

## Context

Multiple teams deploy independently to shared clusters ([ADR-0002](0002-namespace-multi-tenancy-over-cluster-per-team.md)). The platform needs a delivery mechanism that scales with team count without scaling platform-team toil, and gives a reliable answer to "what's running, and why."

The real alternative to GitOps isn't "no automation" — it's CI pipelines running `kubectl apply`/`helm upgrade` directly against the cluster as a last step.

## Decision

Argo CD. Desired state lives entirely in Git; Argo CD reconciles the cluster to match it. New tenants onboard via an `ApplicationSet` that generates one `Application` per team directory.

## Reasoning

- Git becomes the source of truth for what's supposed to be running. Pipeline-driven `kubectl apply` means the true state is whatever the last pipeline run pushed — hard to audit, easy to drift from with a manual change. GitOps detects and corrects drift.
- Onboarding becomes "add a directory under `apps/teams/`," not "provision a new CI/CD pipeline with cluster credentials."
- No tenant CI pipeline needs cluster-write credentials — Argo CD pulls from Git instead of CI pushing to the cluster, so it's the only thing with write access, centrally managed.
- Rollback is `git revert`, not re-running a specific pipeline job with the right parameters.

## Trade-offs accepted

- New operational dependency on Argo CD itself; a misbehaving `ApplicationSet` can affect every tenant at once, so changes to the root/tenant templates get extra scrutiny.
- Teams adjust from "push code, pipeline deploys it" to "push code, pipeline updates a manifest in Git, Argo CD deploys it" — a longer mental chain, offset by audit and drift detection.
- Secrets need a GitOps-compatible pattern, since raw secrets can't live in Git — a required companion decision, not optional. (Resolved in [ADR-0004](0004-secrets-management.md).)

## Alternatives considered

- **CI-pipeline-driven `kubectl apply`/`helm upgrade`** — rejected: credential sprawl across tenant pipelines, weaker drift detection.
- **Flux** — comparable GitOps model. Argo CD chosen for its UI/audit experience being more approachable for teams that aren't Kubernetes specialists.

## Revisit when

Argo CD stops paying for itself. The signals: the root Application or the tenant `ApplicationSet` causes repeated fleet-wide incidents, or the platform shrinks to a team count where a plain deploy pipeline would be less to operate than a controller with write access to everything. Needing canary or blue-green rollouts is not a reason to leave; that argues for adding Argo Rollouts, not for abandoning GitOps.
