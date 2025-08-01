# AI Coding Agent Instructions for DefectDojo on Google Cloud Run

## Architecture Overview

This is a **modular Terraform infrastructure project** deploying DefectDojo (vulnerability management platform) on Google Cloud Platform with enterprise security. The architecture follows a **serverless, security-first design** with auto-scaling Cloud Run, global load balancing, and IP-restricted access.

### Key Components & Data Flow
- **External access** → Global HTTPS Load Balancer (with SSL termination) → Cloud Armor WAF → Cloud Run service
- **DefectDojo container** + Redis sidecar in single Cloud Run service
- **Secrets** stored in Secret Manager, accessed via service account
- **File storage** in Google Cloud Storage bucket
- **Database** is external Neon PostgreSQL (not managed by this Terraform)

## Critical Terraform Patterns

### 1. API Enablement Dependencies
**ALL modules depend on API enablement first**. Every module in `main.tf` includes:
```terraform
depends_on = [google_project_service.required_apis]
```
This prevents race conditions where resources are created before APIs are enabled.

### 2. Secret Management Pattern
Secrets are **never hardcoded**. All sensitive data flows through Secret Manager:
- `random_password` resources generate secrets
- `google_secret_manager_secret` stores them
- Cloud Run accesses via `secret_key_ref` in environment variables

Example from `modules/cloud_run/main.tf`:
```terraform
env {
  name = "DATABASE_URL"
  value_source {
    secret_key_ref {
      secret  = var.neon_database_url_secret_id
      version = "latest"
    }
  }
}
```

### 3. Module Communication Pattern
Modules communicate via **explicit variable passing** in `main.tf`:
- `module.iam` outputs service account email → passed to other modules
- `module.secrets` outputs secret IDs → passed to `cloud_run` module
- `module.cloud_armor` outputs policy name → passed to `load_balancer` module

### 4. Security-First Defaults
- **Cloud Armor**: Default deny-all with IP whitelist only
- **Cloud Run**: No public access (handled via load balancer)
- **IAM**: Least-privilege service accounts with specific roles
- **Storage**: Uniform bucket-level access, no public access

### 5. Serverless Backend Pattern
- **Health Checks**: Remove from `google_compute_backend_service` for Cloud Run backends
- **Network Endpoint Groups**: Use `SERVERLESS` type with `cloud_run` configuration
- **Load Balancer**: Regex patterns must match Cloud Run URL format correctly

## Development Workflows

### Standard Deployment Commands
```bash
# Always validate first
terraform validate

# Plan with explicit var file
terraform plan -var-file="terraform.tfvars"

# Apply with confirmation
terraform apply

# Check deployment status
terraform output defectdojo_url
gcloud run services describe defectdojo --region=us-central1
```

### Testing & Validation
```bash
# Validate configuration
terraform validate

# Format all files
terraform fmt -recursive

# Check service health
gcloud compute backend-services get-health defectdojo-backend --global

# View Cloud Run logs
gcloud run services logs read defectdojo --region=us-central1
```

### Required Configuration Files
- **`terraform.tfvars`**: Copy from `terraform.tfvars.example` and configure:
  - `project_id`: GCP project ID
  - `neon_database_url`: PostgreSQL connection string
  - `allowed_source_ip`: Your IP in CIDR format (e.g., "203.0.113.42/32")

## Critical Integration Points

### External Dependencies
1. **Neon Database**: External PostgreSQL service, connection string required
2. **sslip.io**: Automatic DNS for `{IP}.sslip.io` domains (no setup required)
3. **DefectDojo Container**: Uses official `defectdojo/defectdojo-django:latest` image

### Cross-Component Dependencies
- **Load Balancer** requires Cloud Armor policy AND Cloud Run service URL
- **Cloud Run** requires IAM service account AND Secret Manager secrets
- **SSL Certificate** requires static IP address for domain generation

### DefectDojo-Specific Patterns
- **Environment Variables**: DefectDojo expects `DD_SECRET_KEY` not `SECRET_KEY`
- **Port Configuration**: uWSGI server runs on port 8081 (not 8080)
- **Multi-Container**: DefectDojo + Redis sidecar in single Cloud Run service
- **Health Checks**: Traditional health checks incompatible with serverless backends
- **Database Access**: Both `DATABASE_URL` secret AND individual DB environment variables required

## Project-Specific Conventions

### File Organization
- **Root**: `main.tf` orchestrates all modules with explicit dependencies
- **Modules**: Single-responsibility modules in `modules/` directory
- **Documentation**: Comprehensive docs in `docs/` directory
- **Variables**: Centralized in root `variables.tf`, module-specific vars in each module

### Naming Conventions
- Resources: `{service}-{component}` (e.g., `defectdojo-backend`, `defectdojo-ssl-cert`)
- Modules: Functional names (`cloud_run`, `load_balancer`, not `app`, `lb`)
- Variables: Descriptive with validation (see `variables.tf`)

### Security Patterns
- **IP Restrictions**: Single IP whitelist in Cloud Armor (not IP ranges)
- **Service Accounts**: Dedicated per service with minimal required roles
- **Secrets**: Auto-generated passwords, manual database URL input

## Troubleshooting Patterns

### Common Issues & Solutions
1. **API not enabled**: Check `terraform plan` for API enablement resources
2. **SSL certificate stuck**: DNS propagation takes 10-60 minutes for `.sslip.io`
3. **403 errors**: Usually IP whitelist issue - check `allowed_source_ip` variable
4. **Cloud Run startup failures**: Check logs with `gcloud run services logs read`
5. **SECRET_KEY not populated**: Use `DD_SECRET_KEY` environment variable, not `SECRET_KEY`
6. **Health check failures**: Remove `health_checks` from backend service for serverless endpoints
7. **Port binding errors**: Ensure DefectDojo container uses port 8081, not 8080
8. **Load balancer regex errors**: Cloud Run URL format requires specific regex patterns for service extraction

### Key Diagnostic Commands
```bash
# Check API status
gcloud services list --enabled --filter="name:(cloudrun OR compute)"

# SSL certificate status
gcloud compute ssl-certificates describe defectdojo-ssl-cert

# Security policy rules
gcloud compute security-policies describe defectdojo-security-policy

# Cloud Run service status
gcloud run services describe defectdojo --region=us-central1

# DefectDojo application logs
gcloud run services logs read defectdojo --region=us-central1 --limit=50

# Backend service health (note: not applicable for serverless)
gcloud compute backend-services get-health defectdojo-backend --global
```

## Cost Considerations

This deployment includes **premium GCP services** with fixed monthly costs:
- Global Load Balancer: ~$18-25/month base cost
- Cloud Armor: ~$5-10/month for security policies
- Cloud Run: Pay-per-use (scales to zero)

**Always consider cost impact** when modifying load balancer or Cloud Armor configurations.

---

When working on this codebase, prioritize security configurations and maintain the dependency chain from API enablement → modules → integration testing.
