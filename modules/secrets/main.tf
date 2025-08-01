# =============================================================================
# Secrets Module - Google Secret Manager
# =============================================================================

# =============================================================================
# Neon Database URL Secret
# =============================================================================

resource "google_secret_manager_secret" "neon_database_url" {
  secret_id = "defectdojo-neon-database-url"

  labels = var.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "neon_database_url" {
  secret      = google_secret_manager_secret.neon_database_url.id
  secret_data = var.neon_database_url
}

# =============================================================================
# Django Secret Key
# =============================================================================

resource "google_secret_manager_secret" "secret_key" {
  secret_id = "defectdojo-secret-key"

  labels = var.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "secret_key" {
  secret      = google_secret_manager_secret.secret_key.id
  secret_data = var.secret_key
}

# =============================================================================
# Admin Password Secret
# =============================================================================

resource "google_secret_manager_secret" "admin_password" {
  secret_id = "defectdojo-admin-password"

  labels = var.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "admin_password" {
  secret      = google_secret_manager_secret.admin_password.id
  secret_data = var.admin_password
}

# =============================================================================
# IAM Bindings for Service Account Access
# =============================================================================

resource "google_secret_manager_secret_iam_member" "neon_database_url_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.neon_database_url.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.defectdojo_service_account_email}"
}

resource "google_secret_manager_secret_iam_member" "secret_key_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.secret_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.defectdojo_service_account_email}"
}

resource "google_secret_manager_secret_iam_member" "admin_password_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.admin_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.defectdojo_service_account_email}"
}
