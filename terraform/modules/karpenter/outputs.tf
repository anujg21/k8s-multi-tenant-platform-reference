output "controller_role_arn" {
  value = aws_iam_role.karpenter_controller.arn
}

output "default_node_pool_name" {
  value = kubernetes_manifest.default_node_pool.manifest.metadata.name
}
