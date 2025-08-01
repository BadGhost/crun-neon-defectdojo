# =============================================================================
# Cloud Run Module Variables
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
  description = "The name of the Cloud Run service"
  type        = string
}

variable "container_image" {
  description = "The container image for DefectDojo"
  type        = string
}

variable "service_account_email" {
  description = "Email of the service account to use"
  type        = string
}

variable "neon_database_url_secret_id" {
  description = "The ID of the Neon database URL secret"
  type        = string
}

variable "secret_key_secret_id" {
  description = "The ID of the Django secret key secret"
  type        = string
}

variable "admin_password_secret_id" {
  description = "The ID of the admin password secret"
  type        = string
}

variable "storage_bucket_name" {
  description = "The name of the Cloud Storage bucket"
  type        = string
}

variable "domain_name" {
  description = "The domain name for DefectDojo"
  type        = string
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
