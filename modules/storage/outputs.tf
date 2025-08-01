# =============================================================================
# Storage Module Outputs
# =============================================================================

output "bucket_name" {
  description = "The name of the Cloud Storage bucket"
  value       = google_storage_bucket.defectdojo_files.name
}

output "bucket_url" {
  description = "The URL of the Cloud Storage bucket"
  value       = google_storage_bucket.defectdojo_files.url
}
