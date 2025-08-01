# =============================================================================
# Load Balancer Module Outputs
# =============================================================================

output "load_balancer_ip" {
  description = "The IP address of the load balancer"
  value       = var.static_ip_address
}

output "ssl_certificate_name" {
  description = "The name of the SSL certificate"
  value       = google_compute_managed_ssl_certificate.defectdojo_cert.name
}
