variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_oidc_issuer_url" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "karpenter_helm_chart_version" {
  type    = string
  default = "1.1.1"
}

variable "instance_families" {
  description = "EC2 instance families Karpenter is allowed to choose from when provisioning tenant workload nodes."
  type        = list(string)
  default     = ["m5", "m6i", "c6i", "r6i"]
}

variable "capacity_type" {
  description = "Allowed capacity types for tenant workload nodes."
  type        = list(string)
  default     = ["spot", "on-demand"]
}

variable "consolidation_policy" {
  type    = string
  default = "WhenEmptyOrUnderutilized"
}

variable "disruption_budget_nodes" {
  description = "Max nodes (count or %) Karpenter may voluntarily disrupt (drift/consolidation) at once for the tenant NodePool. Matches Karpenter's own implicit default (10%), set explicitly per production guidance rather than left implicit."
  type        = string
  default     = "10%"
}

variable "tags" {
  type    = map(string)
  default = {}
}
