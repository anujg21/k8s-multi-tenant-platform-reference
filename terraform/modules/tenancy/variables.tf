variable "team_name" {
  description = "Tenant team identifier. Used as the namespace name."
  type        = string
}

variable "quota_cpu_requests" {
  type    = string
  default = "16"
}

variable "quota_memory_requests" {
  type    = string
  default = "32Gi"
}

variable "quota_cpu_limits" {
  type    = string
  default = "32"
}

variable "quota_memory_limits" {
  type    = string
  default = "64Gi"
}

variable "quota_max_pods" {
  type    = number
  default = 100
}

variable "ci_service_account_name" {
  description = "Name of the service account this team's CI pipeline authenticates as, scoped to their namespace only."
  type        = string
  default     = "ci-deployer"
}

variable "labels" {
  type    = map(string)
  default = {}
}
