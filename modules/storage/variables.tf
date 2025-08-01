# =============================================================================
# Storage Module Variables
# =============================================================================

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "service_name" {
  description = "The name of the service"
  type        = string
}

variable "defectdojo_service_account_email" {
  description = "Email of the DefectDojo service account"
  type        = string
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
