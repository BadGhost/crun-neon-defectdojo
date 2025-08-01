# =============================================================================
# Storage Module - Google Cloud Storage
# =============================================================================

# =============================================================================
# Cloud Storage Bucket for DefectDojo Files
# =============================================================================

resource "google_storage_bucket" "defectdojo_files" {
  name          = "${var.project_id}-${var.service_name}-files"
  location      = var.region
  force_destroy = false
  
  labels = var.labels
  
  uniform_bucket_level_access = true
  
  # Versioning for important files
  versioning {
    enabled = true
  }
  
  # Lifecycle management
  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }
  
  lifecycle_rule {
    condition {
      age                   = 30
      num_newer_versions    = 3
    }
    action {
      type = "Delete"
    }
  }
  
  # CORS settings for web access
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
  
  # Encryption
  encryption {
    default_kms_key_name = null
  }
}

# =============================================================================
# IAM Bindings for DefectDojo Service Account
# =============================================================================

resource "google_storage_bucket_iam_member" "defectdojo_storage_admin" {
  bucket = google_storage_bucket.defectdojo_files.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.defectdojo_service_account_email}"
}

resource "google_storage_bucket_iam_member" "defectdojo_storage_viewer" {
  bucket = google_storage_bucket.defectdojo_files.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${var.defectdojo_service_account_email}"
}
