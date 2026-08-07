output "cluster_name" {
  value = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  value = module.eks_cluster.cluster_endpoint
}

output "karpenter_default_node_pool" {
  value = module.karpenter.default_node_pool_name
}

output "tenant_namespaces" {
  value = { for k, v in module.tenant : k => v.namespace }
}
