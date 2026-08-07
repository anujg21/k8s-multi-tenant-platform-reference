output "namespace" {
  value = kubernetes_namespace.team.metadata[0].name
}

output "ci_service_account_name" {
  value = kubernetes_service_account.ci_deployer.metadata[0].name
}
