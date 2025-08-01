# =============================================================================
# Cloud Armor Module Outputs
# =============================================================================

output "policy_name" {
  description = "The name of the Cloud Armor security policy"
  value       = google_compute_security_policy.defectdojo_policy.name
}

output "policy_id" {
  description = "The ID of the Cloud Armor security policy"
  value       = google_compute_security_policy.defectdojo_policy.id
}
