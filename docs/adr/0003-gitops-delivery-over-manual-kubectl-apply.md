# ADR-0003: GitOps delivery (Argo CD) instead of pipeline-driven `kubectl apply`

**Status:** Accepted

## Context

With multiple teams deploying independently to shared multi-tenant clusters (ADR-0002), the platform needs a deployment mechanism that scales in team count without scaling in platform-team toil, and that gives a reliable answer to "what's actually running, and why" at any point in time.

The realistic alternative to GitOps here isn't "no automation" — it's CI pipelines that run `kubectl apply` or `helm upgrade` directly against the cluster as their last step.

## Decision

Adopt Argo CD as the delivery mechanism. The cluster's desired state is defined entirely in Git; Argo CD continuously reconciles the live cluster to match it. New tenants are onboarded via an `ApplicationSet` that generates one Argo CD `Application` per team directory.

## Reasoning

- **Git becomes the single source of truth for "what's supposed to be running."** With pipeline-driven `kubectl apply`, the true state of the cluster is whatever the last successful pipeline run pushed — which is hard to audit and easy for a manual `kubectl` change to silently drift from. With GitOps, drift is detected and either flagged or auto-corrected.
- **Onboarding scales as a data problem, not a pipeline problem.** The `ApplicationSet` pattern means adding a team is "add a directory under `apps/teams/`," not "provision a new CI/CD pipeline with cluster credentials." This matters directly for multi-tenant onboarding speed.
- **Credential blast radius.** Pipeline-driven deploys need cluster-write credentials distributed to every team's CI system. With Argo CD pulling from Git instead of CI pushing to the cluster, no tenant CI pipeline needs direct cluster credentials at all — Argo CD is the only thing with write access, and it's centrally managed by the platform team.
- **Rollback is a `git revert`,** not a re-run of a specific historical pipeline job with the right parameters.

## Trade-offs accepted

- Adds an operational dependency on Argo CD itself being healthy and correctly configured; a misbehaving `ApplicationSet` can affect every tenant at once, so changes to the root/tenant `ApplicationSet` templates get extra scrutiny and staged rollout.
- Teams used to "push code, pipeline deploys it" need to adjust to "push code, pipeline builds and updates a manifest/tag in Git, Argo CD deploys it" — a slightly longer mental chain, offset by the audit and drift-detection benefit.
- Secrets management needs a GitOps-compatible pattern (e.g. sealed secrets or an external secrets operator) since raw secrets can't live in Git — this is a required companion decision, not optional.

## Alternatives considered

- **CI-pipeline-driven `kubectl apply`/`helm upgrade`** — rejected due to credential sprawl across tenant pipelines and weaker drift detection/audit trail.
- **Flux instead of Argo CD** — comparable GitOps model; Argo CD was chosen primarily for its UI/audit experience being more approachable for application teams who aren't Kubernetes specialists, which mattered for a platform serving many non-platform teams directly.
