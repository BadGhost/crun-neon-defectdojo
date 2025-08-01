# =============================================================================
# Cloud Armor Module Variables
# =============================================================================

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "allowed_source_ip" {
  description = "The source IP address allowed to access DefectDojo (CIDR notation)"
  type        = string
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
