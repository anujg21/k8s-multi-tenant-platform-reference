variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "private_subnet_ids" {
  type    = list(string)
  default = []
}

variable "tenant_teams" {
  description = "Teams to onboard as tenants. Add a team here (or, in practice, a directory under apps/teams/) and it gets a namespace, quota, network policy, and scoped RBAC."
  type        = list(string)
  default     = ["team-a", "team-b", "team-c"]
}

variable "tags" {
  type = map(string)
  default = {
    "platform"    = "k8s-multi-tenant-reference"
    "managed-by"  = "terraform"
  }
}
