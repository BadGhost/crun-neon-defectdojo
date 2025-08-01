# =============================================================================
# Secrets Module Variables
# =============================================================================

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "neon_database_url" {
  description = "The Neon PostgreSQL database connection URL"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Django secret key"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "DefectDojo admin password"
  type        = string
  sensitive   = true
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
