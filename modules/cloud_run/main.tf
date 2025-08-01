# =============================================================================
# Cloud Run Module - DefectDojo Service
# =============================================================================

# =============================================================================
# Cloud Run Service
# =============================================================================

resource "google_cloud_run_v2_service" "defectdojo" {
  name     = var.service_name
  location = var.region
  project  = var.project_id
  
  labels = var.labels
  
  template {
    labels = var.labels
    
    # Service account configuration
    service_account = var.service_account_email
    
    # Scaling configuration - scale to zero
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
    
    # Container configuration
    containers {
      image = var.container_image
      
      # Resource limits
      resources {
        limits = {
          cpu    = "2"
          memory = "4Gi"
        }
        cpu_idle = true
        startup_cpu_boost = true
      }
      
      # Port configuration
      ports {
        name           = "http1"
        container_port = 8080
      }
      
      # Environment variables from secrets
      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = var.neon_database_url_secret_id
            version = "latest"
          }
        }
      }
      
      env {
        name = "SECRET_KEY"
        value_source {
          secret_key_ref {
            secret  = var.secret_key_secret_id
            version = "latest"
          }
        }
      }
      
      env {
        name = "DD_ADMIN_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.admin_password_secret_id
            version = "latest"
          }
        }
      }
      
      # Standard environment variables
      env {
        name  = "DD_DEBUG"
        value = "False"
      }
      
      env {
        name  = "DD_ALLOWED_HOSTS"
        value = var.domain_name
      }
      
      env {
        name  = "DD_DATABASE_ENGINE"
        value = "django.db.backends.postgresql"
      }
      
      env {
        name  = "DD_MEDIA_ROOT"
        value = "/app/media"
      }
      
      env {
        name  = "DD_STATIC_ROOT"
        value = "/app/static"
      }
      
      env {
        name  = "DD_CELERY_BROKER_URL"
        value = "redis://localhost:6379/0"
      }
      
      env {
        name  = "DD_CELERY_RESULT_BACKEND"
        value = "redis://localhost:6379/0"
      }
      
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      
      env {
        name  = "GCS_BUCKET_NAME"
        value = var.storage_bucket_name
      }
      
      # Health check configuration
      startup_probe {
        http_get {
          path = "/login"
          port = 8080
        }
        initial_delay_seconds = 30
        timeout_seconds       = 10
        period_seconds        = 10
        failure_threshold     = 3
      }
      
      liveness_probe {
        http_get {
          path = "/login"
          port = 8080
        }
        initial_delay_seconds = 60
        timeout_seconds       = 10
        period_seconds        = 30
        failure_threshold     = 3
      }
    }
    
    # Container for Redis (required by DefectDojo)
    containers {
      name  = "redis"
      image = "redis:7-alpine"
      
      resources {
        limits = {
          cpu    = "0.5"
          memory = "512Mi"
        }
      }
      
      ports {
        name           = "redis"
        container_port = 6379
      }
    }
  }
  
  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
}

# =============================================================================
# IAM Policy for Public Access (Controlled by Load Balancer)
# =============================================================================

resource "google_cloud_run_service_iam_member" "public_access" {
  service  = google_cloud_run_v2_service.defectdojo.name
  location = google_cloud_run_v2_service.defectdojo.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
