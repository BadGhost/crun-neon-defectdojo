# =============================================================================
# Secrets Module Outputs
# =============================================================================

output "neon_database_url_secret_id" {
  description = "The ID of the Neon database URL secret"
  value       = google_secret_manager_secret.neon_database_url.secret_id
}

output "secret_key_secret_id" {
  description = "The ID of the Django secret key secret"
  value       = google_secret_manager_secret.secret_key.secret_id
}

output "admin_password_secret_id" {
  description = "The ID of the admin password secret"
  value       = google_secret_manager_secret.admin_password.secret_id
}

output "admin_password_secret_name" {
  description = "The name of the admin password secret"
  value       = google_secret_manager_secret.admin_password.secret_id
  sensitive   = true
}
