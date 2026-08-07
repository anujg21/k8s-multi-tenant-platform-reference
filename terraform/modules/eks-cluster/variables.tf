variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes control plane version."
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "VPC to launch the cluster into."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for worker nodes and the control plane ENIs."
  type        = list(string)
}

variable "static_node_group_instance_types" {
  description = "Instance types for the minimal static node group that hosts cluster-critical add-ons (must not depend on Karpenter's own scheduling)."
  type        = list(string)
  default     = ["m5.large"]
}

variable "static_node_group_min_size" {
  type    = number
  default = 2
}

variable "static_node_group_max_size" {
  type    = number
  default = 4
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}
