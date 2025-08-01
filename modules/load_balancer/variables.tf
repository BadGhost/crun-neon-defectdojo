# =============================================================================
# Load Balancer Module Variables
# =============================================================================

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "service_name" {
  description = "The name of the service"
  type        = string
}

variable "domain_name" {
  description = "The domain name for DefectDojo"
  type        = string
}

variable "cloud_run_service_url" {
  description = "The URL of the Cloud Run service"
  type        = string
}

variable "static_ip_address" {
  description = "The static IP address for the load balancer"
  type        = string
}

variable "cloud_armor_policy_name" {
  description = "The name of the Cloud Armor security policy"
  type        = string
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
