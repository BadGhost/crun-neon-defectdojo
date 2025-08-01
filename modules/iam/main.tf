# =============================================================================
# IAM Module - Service Accounts and IAM Bindings
# =============================================================================

# =============================================================================
# Service Account for DefectDojo Cloud Run Service
# =============================================================================

resource "google_service_account" "defectdojo" {
  account_id   = "${var.service_name}-cloudrun"
  display_name = "DefectDojo Cloud Run Service Account"
  description  = "Service account for DefectDojo running on Cloud Run"
}

# =============================================================================
# IAM Roles for DefectDojo Service Account
# =============================================================================

# Secret Manager Secret Accessor - to read secrets
resource "google_project_iam_member" "defectdojo_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.defectdojo.email}"
}

# Cloud SQL Client - in case future database migrations are needed
resource "google_project_iam_member" "defectdojo_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.defectdojo.email}"
}

# Monitoring Metric Writer - for application metrics
resource "google_project_iam_member" "defectdojo_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.defectdojo.email}"
}

# Logging Writer - for application logs
resource "google_project_iam_member" "defectdojo_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.defectdojo.email}"
}

# Cloud Trace Agent - for distributed tracing
resource "google_project_iam_member" "defectdojo_trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.defectdojo.email}"
}
