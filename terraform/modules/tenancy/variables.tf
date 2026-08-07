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

variable "pod_security_enforce_level" {
  description = "Pod Security Standard enforced on this tenant's namespace (pod-security.kubernetes.io/enforce). 'baseline' blocks known privilege escalations while staying compatible with most workloads; 'restricted' is stricter and may require teams to adjust manifests. See docs/security-review.md."
  type        = string
  default     = "baseline"

  validation {
    condition     = contains(["privileged", "baseline", "restricted"], var.pod_security_enforce_level)
    error_message = "pod_security_enforce_level must be one of: privileged, baseline, restricted."
  }
}
