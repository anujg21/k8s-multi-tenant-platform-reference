# Per-team tenancy boundary: namespace + resource quota + default-deny
# network policy + RBAC scoped to that namespace only.
#
# One call to this module = one onboarded team. See
# docs/adr/0002-namespace-multi-tenancy-over-cluster-per-team.md for why
# this boundary is a namespace and not a dedicated cluster.

resource "kubernetes_namespace" "team" {
  metadata {
    name = var.team_name
    labels = merge(var.labels, {
      "platform.internal/tenant" = var.team_name
    })
  }
}

# --- Quota: bounds one team's blast radius on shared capacity --------------

resource "kubernetes_resource_quota" "team" {
  metadata {
    name      = "${var.team_name}-quota"
    namespace = kubernetes_namespace.team.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = var.quota_cpu_requests
      "requests.memory" = var.quota_memory_requests
      "limits.cpu"      = var.quota_cpu_limits
      "limits.memory"   = var.quota_memory_limits
      "pods"            = tostring(var.quota_max_pods)
    }
  }
}

resource "kubernetes_limit_range" "team" {
  metadata {
    name      = "${var.team_name}-default-limits"
    namespace = kubernetes_namespace.team.metadata[0].name
  }

  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "500m"
        memory = "512Mi"
      }
      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }
    }
  }
}

# --- Network isolation: default-deny cross-namespace traffic ---------------

resource "kubernetes_network_policy" "default_deny_ingress" {
  metadata {
    name      = "default-deny-ingress"
    namespace = kubernetes_namespace.team.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]
    # No ingress rules = deny by default. Teams opt into specific ingress
    # (e.g. from an ingress-controller namespace, or a named peer team)
    # via additional NetworkPolicy resources layered in their own
    # application manifests — this module only sets the default posture.
  }
}

resource "kubernetes_network_policy" "allow_same_namespace" {
  metadata {
    name      = "allow-same-namespace"
    namespace = kubernetes_namespace.team.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "platform.internal/tenant" = var.team_name
          }
        }
      }
    }
  }
}

# --- RBAC: CI pipeline credentials scoped to this namespace only ----------

resource "kubernetes_service_account" "ci_deployer" {
  metadata {
    name      = var.ci_service_account_name
    namespace = kubernetes_namespace.team.metadata[0].name
  }
}

resource "kubernetes_role" "ci_deployer" {
  metadata {
    name      = "${var.ci_service_account_name}-role"
    namespace = kubernetes_namespace.team.metadata[0].name
  }

  rule {
    api_groups = ["apps", ""]
    resources  = ["deployments", "services", "configmaps", "pods", "pods/log"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }
}

resource "kubernetes_role_binding" "ci_deployer" {
  metadata {
    name      = "${var.ci_service_account_name}-binding"
    namespace = kubernetes_namespace.team.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.ci_deployer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.ci_deployer.metadata[0].name
    namespace = kubernetes_namespace.team.metadata[0].name
  }
}
