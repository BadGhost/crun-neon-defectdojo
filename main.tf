# =============================================================================
# Root Module for DefectDojo on Google Cloud Run
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# =============================================================================
# Provider Configuration
# =============================================================================

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# =============================================================================
# Enable Required APIs
# =============================================================================

resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",
    "compute.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
    "certificatemanager.googleapis.com",
    "networkservices.googleapis.com",
    "cloudbuild.googleapis.com"
  ])

  project = var.project_id
  service = each.value

  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_on_destroy         = false
  disable_dependent_services = false
}

# =============================================================================
# Local Values
# =============================================================================

locals {
  service_name = "defectdojo"
  domain_name  = "${google_compute_global_address.defectdojo_ip.address}.sslip.io"

  labels = {
    environment = var.environment
    application = "defectdojo"
    managed_by  = "terraform"
  }
}

# =============================================================================
# Random Password Generation
# =============================================================================

resource "random_password" "secret_key" {
  length  = 50
  special = true
}

resource "random_password" "admin_password" {
  length  = 16
  special = true
}

# =============================================================================
# Module Instantiations
# =============================================================================

module "iam" {
  source = "./modules/iam"

  project_id   = var.project_id
  service_name = local.service_name
  labels       = local.labels

  depends_on = [google_project_service.required_apis]
}

module "secrets" {
  source = "./modules/secrets"

  project_id                       = var.project_id
  neon_database_url                = var.neon_database_url
  secret_key                       = random_password.secret_key.result
  admin_password                   = random_password.admin_password.result
  defectdojo_service_account_email = module.iam.defectdojo_service_account_email
  labels                           = local.labels

  depends_on = [google_project_service.required_apis]
}

module "storage" {
  source = "./modules/storage"

  project_id   = var.project_id
  region       = var.region
  service_name = local.service_name
  labels       = local.labels

  defectdojo_service_account_email = module.iam.defectdojo_service_account_email

  depends_on = [google_project_service.required_apis]
}

module "cloud_run" {
  source = "./modules/cloud_run"

  project_id            = var.project_id
  region                = var.region
  service_name          = local.service_name
  container_image       = var.container_image
  service_account_email = module.iam.defectdojo_service_account_email

  # Secret references
  neon_database_url_secret_id = module.secrets.neon_database_url_secret_id
  secret_key_secret_id        = module.secrets.secret_key_secret_id
  admin_password_secret_id    = module.secrets.admin_password_secret_id

  # Storage bucket
  storage_bucket_name = module.storage.bucket_name

  # Domain configuration
  domain_name = local.domain_name

  labels = local.labels

  depends_on = [google_project_service.required_apis]
}

module "cloud_armor" {
  source = "./modules/cloud_armor"

  project_id        = var.project_id
  allowed_source_ip = var.allowed_source_ip
  labels            = local.labels

  depends_on = [google_project_service.required_apis]
}

module "load_balancer" {
  source = "./modules/load_balancer"

  project_id              = var.project_id
  service_name            = local.service_name
  domain_name             = local.domain_name
  cloud_run_service_url   = module.cloud_run.service_url
  static_ip_address       = google_compute_global_address.defectdojo_ip.address
  cloud_armor_policy_name = module.cloud_armor.policy_name
  labels                  = local.labels

  depends_on = [google_project_service.required_apis]
}

# =============================================================================
# Global Static IP Address
# =============================================================================

resource "google_compute_global_address" "defectdojo_ip" {
  name         = "${local.service_name}-global-ip"
  description  = "Static IP address for DefectDojo load balancer"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}
