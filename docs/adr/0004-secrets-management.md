# ADR-0004: External Secrets Operator for secrets management

**Status:** Accepted

## Context

ADR-0003 named this as unresolved: GitOps needs a secrets story, since raw secrets can't live in Git — but nothing ever decided what that story was. Right now the only path into a tenant namespace is committing plaintext to Git.

Two real options exist: **Sealed Secrets** (encrypt client-side, commit the ciphertext) and **External Secrets Operator** (sync from an external store like AWS Secrets Manager; Git holds only a reference to the key).

## Decision

External Secrets Operator, with a namespace-scoped `SecretStore` per tenant pointing at AWS Secrets Manager.

## Reasoning

- Git never holds secret material, encrypted or not — a narrower audit surface than Sealed Secrets' committed ciphertext.
- A `SecretStore` per tenant fits the existing per-tenant boundary already used for quota and network policy; ESO's own multi-tenancy guidance recommends this over one shared `ClusterSecretStore`.
- Sealed Secrets needs `kubeseal` run somewhere with plaintext access before commit — a manual step GitOps is supposed to eliminate.
- Rotation is just a Secrets Manager update with ESO. Sealed Secrets needs a re-seal and re-commit for every rotation.

## Trade-offs accepted

- Real external dependency (Secrets Manager, IAM wiring) that Sealed Secrets doesn't need — a smaller adopter might reasonably start there instead.
- Per-tenant IAM scoping work at onboarding, following the same IRSA pattern already used for the Karpenter controller.
- This is a decision, not code. Not yet implemented as Terraform/Helm — see [production-readiness.md](../production-readiness.md).

## Alternatives considered

- **Sealed Secrets** — simpler, still GitOps-compatible, weaker at multi-tenant scale and rotation.
- **Plaintext in Git** — exactly what ADR-0003 already warns against.
- **Vault + Agent Injector** — comparable model, but adds a stateful system this AWS-native platform doesn't otherwise need.

## Revisit when

The platform has to run outside AWS. ESO supports other backends, but the per-tenant IAM scoping is Secrets Manager specific and would need a redesign. Also revisit if the fleet shrinks to where an operator plus IAM wiring costs more than re-sealing a handful of secrets by hand; Sealed Secrets wins at that size, as the trade-offs above already concede.
