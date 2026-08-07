# ADR-0005: Pod Security Admission plus Kyverno

**Status:** Accepted

## Context

RBAC controls who can create objects, not what's in them. Nothing stopped a privileged pod, `hostNetwork`, or a `hostPath` mount from being deployed by any tenant with namespace write access — see [security-review.md](../security-review.md).

Options: **Pod Security Admission** (built into the API server, namespace-label driven, three fixed tiers), **Kyverno** (policy engine, native YAML), **OPA Gatekeeper** (policy engine, Rego).

## Decision

PSA at `baseline` as a non-negotiable floor — implemented. Kyverno for anything beyond PSA's scope (image provenance, required labels, custom rules) — decided, not yet implemented.

## Reasoning

- PSA needs zero new infrastructure and closes the highest-severity gap immediately: just labels on a resource already in the module.
- PSA's tiers are fixed — no image checks, no custom rules. A real gap as this platform grows.
- Kyverno policies are plain YAML. ADR-0003 already chose Argo CD partly for being approachable to teams that aren't Kubernetes specialists; the same logic favors Kyverno over Gatekeeper's Rego.
- Kyverno also mutates and generates resources, which Gatekeeper doesn't — it could auto-generate a default `NetworkPolicy` or inject a missing label, extending the "platform doesn't trust the app to self-limit" principle already stated in `architecture.md`.

## Trade-offs accepted

- Kyverno is a new controller to run and patch.
- A new failure mode for on-call: admission rejections, on top of RBAC and quota failures.
- PSA is implemented; Kyverno is a documented direction only.

## Alternatives considered

- **OPA Gatekeeper** — comparable capability, rejected on audience fit (Rego vs. YAML).
- **PSA alone** — insufficient once you need anything beyond built-in pod security.
- **PodSecurityPolicy** — removed from Kubernetes in 1.25, not viable.
