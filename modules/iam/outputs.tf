# =============================================================================
# IAM Module Outputs
# =============================================================================

output "defectdojo_service_account_email" {
  description = "Email of the DefectDojo service account"
  value       = google_service_account.defectdojo.email
}

output "defectdojo_service_account_id" {
  description = "ID of the DefectDojo service account"
  value       = google_service_account.defectdojo.id
}
