# =============================================================================
# Cloud Armor Module - Security Policy
# =============================================================================

# =============================================================================
# Cloud Armor Security Policy
# =============================================================================

resource "google_compute_security_policy" "defectdojo_policy" {
  name        = "defectdojo-security-policy"
  description = "Cloud Armor policy for DefectDojo - restricts access to specific IP"
  project     = var.project_id

  # Default rule - deny all traffic
  rule {
    action   = "deny(403)"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default deny rule"
  }

  # Allow traffic from specified source IP
  rule {
    action   = "allow"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = [var.allowed_source_ip]
      }
    }
    description = "Allow access from specified source IP"
  }

  # Additional security rules

  # Rate limiting rule
  rule {
    action   = "rate_based_ban"
    priority = "2000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      ban_duration_sec = 300
    }
    description = "Rate limiting - max 100 requests per minute per IP"
  }

  # Block common attack patterns
  rule {
    action   = "deny(403)"
    priority = "3000"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable')"
      }
    }
    description = "Block XSS attacks"
  }

  rule {
    action   = "deny(403)"
    priority = "3001"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable')"
      }
    }
    description = "Block SQL injection attacks"
  }

  rule {
    action   = "deny(403)"
    priority = "3002"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-stable')"
      }
    }
    description = "Block local file inclusion attacks"
  }

  rule {
    action   = "deny(403)"
    priority = "3003"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rfi-stable')"
      }
    }
    description = "Block remote file inclusion attacks"
  }

  # Block suspicious user agents
  rule {
    action   = "deny(403)"
    priority = "4000"
    match {
      expr {
        expression = "has(request.headers['user-agent']) && request.headers['user-agent'].matches('curl|wget|python|scanner|bot')"
      }
    }
    description = "Block suspicious user agents"
  }
}
