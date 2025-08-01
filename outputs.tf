# =============================================================================
# Output Values
# =============================================================================

output "defectdojo_url" {
  description = "The URL to access DefectDojo"
  value       = "https://${local.domain_name}"
}

output "static_ip_address" {
  description = "The static IP address assigned to the load balancer"
  value       = google_compute_global_address.defectdojo_ip.address
}

output "admin_password_secret_name" {
  description = "The name of the secret containing the admin password"
  value       = module.secrets.admin_password_secret_name
  sensitive   = true
}

output "storage_bucket_name" {
  description = "The name of the Cloud Storage bucket for DefectDojo files"
  value       = module.storage.bucket_name
}

output "cloud_run_service_url" {
  description = "The Cloud Run service URL"
  value       = module.cloud_run.service_url
}

output "load_balancer_ip" {
  description = "The load balancer IP address"
  value       = google_compute_global_address.defectdojo_ip.address
}
