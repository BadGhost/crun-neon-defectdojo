# =============================================================================
# Input Variables
# =============================================================================

variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string
}

variable "region" {
  description = "The GCP region where resources will be deployed"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "neon_database_url" {
  description = "The Neon PostgreSQL database connection URL"
  type        = string
  sensitive   = true
}

variable "container_image" {
  description = "The container image for DefectDojo"
  type        = string
  default     = "us-central1-docker.pkg.dev/your-defectdojo-project/defectdojo-repo/defectdojo-custom:v3"
}

variable "allowed_source_ip" {
  description = "The source IP address allowed to access DefectDojo (CIDR notation)"
  type        = string
  validation {
    condition     = can(cidrhost(var.allowed_source_ip, 0))
    error_message = "The allowed_source_ip must be a valid CIDR notation (e.g., 203.0.113.0/32)."
  }
}
