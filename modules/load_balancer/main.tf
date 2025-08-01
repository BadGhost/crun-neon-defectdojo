# =============================================================================
# Load Balancer Module - Global HTTPS Load Balancer
# =============================================================================

# =============================================================================
# SSL Certificate
# =============================================================================

resource "google_compute_managed_ssl_certificate" "defectdojo_cert" {
  name = "${var.service_name}-ssl-cert"

  managed {
    domains = [var.domain_name]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Backend Service
# =============================================================================

resource "google_compute_backend_service" "defectdojo_backend" {
  name                  = "${var.service_name}-backend"
  description           = "Backend service for DefectDojo"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  enable_cdn            = false
  load_balancing_scheme = "EXTERNAL_MANAGED"

  # Cloud Armor security policy
  security_policy = "projects/${var.project_id}/global/securityPolicies/${var.cloud_armor_policy_name}"

  backend {
    group = google_compute_region_network_endpoint_group.defectdojo_neg.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  # Note: Health checks are not compatible with serverless backends
}

# =============================================================================
# Network Endpoint Group for Cloud Run
# =============================================================================

resource "google_compute_region_network_endpoint_group" "defectdojo_neg" {
  name                  = "${var.service_name}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = local.region

  cloud_run {
    service = local.cloud_run_service_name
  }
}

# =============================================================================
# Health Check
# =============================================================================

resource "google_compute_health_check" "defectdojo_health_check" {
  name               = "${var.service_name}-health-check"
  check_interval_sec = 30
  timeout_sec        = 10

  http_health_check {
    port         = 8080
    request_path = "/login"
  }
}

# =============================================================================
# URL Map
# =============================================================================

resource "google_compute_url_map" "defectdojo_url_map" {
  name            = "${var.service_name}-url-map"
  description     = "URL map for DefectDojo"
  default_service = google_compute_backend_service.defectdojo_backend.id

  # Redirect HTTP to HTTPS
  host_rule {
    hosts        = [var.domain_name]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.defectdojo_backend.id
  }
}

# =============================================================================
# HTTPS Proxy
# =============================================================================

resource "google_compute_target_https_proxy" "defectdojo_https_proxy" {
  name             = "${var.service_name}-https-proxy"
  url_map          = google_compute_url_map.defectdojo_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.defectdojo_cert.id]

  ssl_policy = google_compute_ssl_policy.defectdojo_ssl_policy.id
}

# =============================================================================
# HTTP Proxy (for redirect to HTTPS)
# =============================================================================

resource "google_compute_url_map" "defectdojo_http_redirect" {
  name = "${var.service_name}-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "defectdojo_http_proxy" {
  name    = "${var.service_name}-http-proxy"
  url_map = google_compute_url_map.defectdojo_http_redirect.id
}

# =============================================================================
# SSL Policy
# =============================================================================

resource "google_compute_ssl_policy" "defectdojo_ssl_policy" {
  name            = "${var.service_name}-ssl-policy"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

# =============================================================================
# Global Forwarding Rules
# =============================================================================

resource "google_compute_global_forwarding_rule" "defectdojo_https" {
  name                  = "${var.service_name}-https-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.defectdojo_https_proxy.id
  ip_address            = var.static_ip_address
}

resource "google_compute_global_forwarding_rule" "defectdojo_http" {
  name                  = "${var.service_name}-http-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.defectdojo_http_proxy.id
  ip_address            = var.static_ip_address
}

# =============================================================================
# Local Values
# =============================================================================

locals {
  region                 = "us-central1"  # Extract from Cloud Run URL or set explicitly
  cloud_run_service_name = regex("https://([^-]+)", var.cloud_run_service_url)[0]
}
