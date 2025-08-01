# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with your DefectDojo deployment.

## Critical: API Enablement Permission Issues

### Problem: Cannot Enable Cloud Run API
If you're getting permission denied errors when trying to enable services like `cloudrun.googleapis.com`:

```
ERROR: (gcloud.services.enable) PERMISSION_DENIED: Not found or permission denied for service(s): cloudrun.googleapis.com
```

#### Immediate Solutions:

1. **Use the Google Cloud Console** (Recommended):
   - Go to [Google Cloud Console](https://console.cloud.google.com)
   - Navigate to "APIs & Services" → "Library"
   - Search for and enable each service manually:
     - Cloud Run API
     - Compute Engine API  
     - Secret Manager API
     - Cloud Storage API
     - Certificate Manager API
     - Network Services API

2. **Wait for Project Propagation**:
   ```bash
   # New projects need 5-10 minutes for full service availability
   echo "Waiting for project propagation..."
   sleep 300  # Wait 5 minutes
   gcloud services enable cloudrun.googleapis.com
   ```

3. **Fix Quota Project Issues**:
   ```bash
   gcloud auth application-default set-quota-project your-defectdojo-project
   gcloud config set project your-defectdojo-project
   ```

4. **Alternative: Enable Services via Terraform**:
   Add this to your main.tf before other resources:
   ```hcl
   # Enable required APIs
   resource "google_project_service" "required_apis" {
     for_each = toset([
       "cloudrun.googleapis.com",
       "compute.googleapis.com", 
       "secretmanager.googleapis.com",
       "storage.googleapis.com"
     ])
     
     project = var.project_id
     service = each.value
     disable_on_destroy = false
   }
   ```

## Quick Diagnostics

### Health Check Script

Run this comprehensive health check to identify issues:

```bash
#!/bin/bash
# Save as health-check.sh and run: chmod +x health-check.sh && ./health-check.sh

echo "=== DefectDojo Health Check ==="
echo "Date: $(date)"
echo ""

# Check Terraform state
echo "1. Terraform State:"
terraform show -json | jq -r '.values.root_module.resources[] | select(.type == "google_cloud_run_v2_service") | .values.name'

# Check Cloud Run service
echo ""
echo "2. Cloud Run Service Status:"
gcloud run services describe defectdojo --region=us-central1 --format="value(status.conditions[0].type,status.conditions[0].status)"

# Check SSL certificate
echo ""
echo "3. SSL Certificate Status:"
gcloud compute ssl-certificates list --format="table(name,managed.status,managed.domains)"

# Check load balancer
echo ""
echo "4. Load Balancer Health:"
gcloud compute backend-services get-health defectdojo-backend --global 2>/dev/null || echo "Backend health check failed"

# Check secrets
echo ""
echo "5. Secret Manager Access:"
gcloud secrets versions access latest --secret="defectdojo-neon-database-url" > /dev/null && echo "Database secret: OK" || echo "Database secret: FAILED"

# Check Cloud Armor
echo ""
echo "6. Cloud Armor Policy:"
gcloud compute security-policies describe defectdojo-security-policy --format="value(name,fingerprint)" 2>/dev/null || echo "Security policy not found"

echo ""
echo "=== Health Check Complete ==="
```

## Common Issues and Solutions

### 1. SSL Certificate Issues

#### Problem: "Your connection is not private" error
**Symptoms:**
- Browser shows SSL/TLS errors
- HTTPS requests fail
- Certificate status shows "PROVISIONING"

**Diagnosis:**
```bash
# Check certificate status
gcloud compute ssl-certificates describe defectdojo-ssl-cert --global --format="yaml"

# Check DNS resolution
nslookup $(terraform output -raw static_ip_address).sslip.io
```

**Solutions:**
```bash
# Wait for certificate provisioning (can take 10-20 minutes)
# If stuck for >30 minutes, recreate certificate:
terraform apply -replace="module.load_balancer.google_compute_managed_ssl_certificate.defectdojo_cert"

# Verify domain format is correct
terraform output defectdojo_url
```

### 2. Cloud Run Service Not Starting

#### Problem: Service fails to start or becomes unhealthy
**Symptoms:**
- 502/503 errors from load balancer
- Health checks failing
- Service marked as "not ready"

**Diagnosis:**
```bash
# Check service logs
gcloud run services logs read defectdojo --region=us-central1 --limit=100

# Check service configuration
gcloud run services describe defectdojo --region=us-central1
```

**Common Solutions:**

**Database Connection Issues:**
```bash
# Test database connectivity
DB_URL=$(gcloud secrets versions access latest --secret="defectdojo-neon-database-url")
psql "$DB_URL" -c "SELECT version();"

# If connection fails, verify Neon database is running and URL is correct
```

**Memory/CPU Issues:**
```bash
# Check if container is running out of resources
gcloud run services describe defectdojo --region=us-central1 --format="yaml(spec.template.spec.template.spec.containers[0].resources)"

# Increase resources temporarily
terraform apply -var="container_cpu=4" -var="container_memory=8Gi"
```

**Environment Variables:**
```bash
# Verify all secrets are accessible
for secret in defectdojo-neon-database-url defectdojo-secret-key defectdojo-admin-password; do
    echo "Testing $secret:"
    gcloud secrets versions access latest --secret="$secret" > /dev/null && echo "  ✓ OK" || echo "  ✗ FAILED"
done
```

### 3. Load Balancer 502/503 Errors

#### Problem: Load balancer returns server errors
**Symptoms:**
- HTTP 502 Bad Gateway
- HTTP 503 Service Unavailable
- Intermittent connectivity

**Diagnosis:**
```bash
# Check backend service health
gcloud compute backend-services get-health defectdojo-backend --global

# Check NEG status
gcloud compute network-endpoint-groups list --filter="name~defectdojo"

# Check forwarding rules
gcloud compute forwarding-rules list --global --filter="name~defectdojo"
```

**Solutions:**
```bash
# Recreate network endpoint group
terraform apply -replace="module.load_balancer.google_compute_region_network_endpoint_group.defectdojo_neg"

# Check health check configuration
gcloud compute health-checks describe defectdojo-health-check --global
```

### 4. Cloud Armor Access Denied

#### Problem: Legitimate traffic blocked by Cloud Armor
**Symptoms:**
- HTTP 403 Forbidden errors
- Users from allowed IP range cannot access
- Inconsistent access patterns

**Diagnosis:**
```bash
# Check Cloud Armor logs
gcloud logging read 'resource.type="http_load_balancer" AND jsonPayload.enforcedSecurityPolicy.name="defectdojo-security-policy"' --limit=50

# Verify your current IP
curl ifconfig.me

# Check security policy rules
gcloud compute security-policies describe defectdojo-security-policy
```

**Solutions:**
```bash
# Update allowed IP if your IP changed
terraform apply -var="allowed_source_ip=NEW.IP.ADDRESS/32"

# Temporarily allow broader access for testing
terraform apply -var="allowed_source_ip=0.0.0.0/0"
# WARNING: This allows global access - use only for debugging
```

### 5. Secret Manager Access Issues

#### Problem: Application cannot access secrets
**Symptoms:**
- Environment variables are empty
- Database connection fails
- Authentication errors

**Diagnosis:**
```bash
# Check service account permissions
SA_EMAIL=$(terraform output -raw defectdojo_service_account_email)
gcloud iam service-accounts get-iam-policy "$SA_EMAIL"

# Test secret access
gcloud secrets versions access latest --secret="defectdojo-neon-database-url" --impersonate-service-account="$SA_EMAIL"
```

**Solutions:**
```bash
# Recreate IAM bindings
terraform apply -replace="module.secrets.google_secret_manager_secret_iam_member.neon_database_url_access"

# Verify secret content
gcloud secrets versions access latest --secret="defectdojo-neon-database-url"
```

### 6. High Costs / Unexpected Charges

#### Problem: Monthly bill higher than expected
**Symptoms:**
- Unexpected GCP charges
- High load balancer costs
- Excessive Cloud Run usage

**Diagnosis:**
```bash
# Check current month costs
gcloud billing budgets list --billing-account=BILLING_ACCOUNT_ID

# Check resource usage
gcloud monitoring metrics list --filter="metric.type=~'.*cloud_run.*'"
```

**Solutions:**
```bash
# Review and optimize scaling settings
# Check for runaway instances
gcloud run services describe defectdojo --region=us-central1 --format="yaml(spec.template.spec.template.spec.scaling)"

# Implement cost controls
terraform apply -var="max_instance_count=3"
```

## Advanced Debugging

### Enable Debug Logging

```bash
# Enable Cloud Run debug logs
gcloud run services update defectdojo \
    --region=us-central1 \
    --set-env-vars="DD_DEBUG=True,DJANGO_LOG_LEVEL=DEBUG"

# Enable load balancer logging
gcloud compute backend-services update defectdojo-backend \
    --global \
    --enable-logging \
    --logging-sample-rate=1.0
```

### Database Debugging

```bash
# Connect to Neon database directly
DB_URL=$(gcloud secrets versions access latest --secret="defectdojo-neon-database-url")
psql "$DB_URL"

# Run database diagnostics
psql "$DB_URL" -c "\l"  # List databases
psql "$DB_URL" -c "\dt" # List tables
psql "$DB_URL" -c "SELECT COUNT(*) FROM django_migrations;" # Check migrations
```

### Network Debugging

```bash
# Test connectivity from Cloud Shell
curl -I "https://$(terraform output -raw static_ip_address).sslip.io"

# Test with specific user agent
curl -H "User-Agent: Mozilla/5.0" -I "https://$(terraform output -raw defectdojo_url)"

# Test from different regions
gcloud compute instances create debug-vm --zone=us-east1-b --machine-type=e2-micro
gcloud compute ssh debug-vm --zone=us-east1-b --command="curl -I https://$(terraform output -raw defectdojo_url)"
gcloud compute instances delete debug-vm --zone=us-east1-b --quiet
```

## Recovery Procedures

### Complete Environment Recovery

```bash
# 1. Backup current state
terraform state pull > terraform-state-backup.json

# 2. Destroy and recreate
terraform destroy
terraform apply

# 3. Restore data if needed
# (Neon database and Cloud Storage should be preserved)
```

### Partial Component Recovery

```bash
# Recreate only Cloud Run service
terraform apply -replace="module.cloud_run.google_cloud_run_v2_service.defectdojo"

# Recreate only load balancer
terraform apply -replace="module.load_balancer"

# Recreate only Cloud Armor policy
terraform apply -replace="module.cloud_armor.google_compute_security_policy.defectdojo_policy"
```

### Emergency Access Recovery

If you're completely locked out:

```bash
# 1. Temporarily disable Cloud Armor
gcloud compute security-policies delete defectdojo-security-policy

# 2. Access the service directly via Cloud Run URL
gcloud run services describe defectdojo --region=us-central1 --format="value(status.url)"

# 3. After fixing issues, recreate security policy
terraform apply
```

## Monitoring and Alerting

### Set Up Proactive Monitoring

```bash
# Create uptime check
gcloud alpha monitoring uptime-checks create "https://$(terraform output -raw defectdojo_url)" \
    --check-interval=60 \
    --timeout=10 \
    --display-name="DefectDojo Uptime"

# Create alerting policy
gcloud alpha monitoring policies create \
    --policy-from-file=monitoring-policy.yaml
```

### Log Analysis Queries

```bash
# Find all 4xx/5xx errors
gcloud logging read 'resource.type="http_load_balancer" AND httpRequest.status>=400' --limit=100

# Find Cloud Armor blocks
gcloud logging read 'resource.type="http_load_balancer" AND jsonPayload.enforcedSecurityPolicy.name="defectdojo-security-policy"' --limit=50

# Find Cloud Run errors
gcloud logging read 'resource.type="cloud_run_revision" AND severity>=ERROR' --limit=100
```

## Prevention Best Practices

### 1. Regular Health Checks
- Run health check script weekly
- Monitor SSL certificate expiration
- Check resource usage trends

### 2. Configuration Management
- Always test changes in a development environment
- Use Terraform plan before apply
- Keep backups of working configurations

### 3. Security Monitoring
- Review Cloud Armor logs monthly
- Monitor for unusual access patterns
- Keep IP allowlists updated

### 4. Cost Management
- Set up billing alerts
- Review monthly usage reports
- Optimize resource allocations based on usage

## Getting Help

If this guide doesn't resolve your issue:

1. **Check Logs**: Always start with service logs
2. **Search Documentation**: Check Google Cloud and DefectDojo docs
3. **Community Support**: Ask on relevant forums with specific error messages
4. **Professional Support**: Consider Google Cloud support for critical issues

### Useful Resources

- [Google Cloud Run Troubleshooting](https://cloud.google.com/run/docs/troubleshooting)
- [Load Balancer Troubleshooting](https://cloud.google.com/load-balancing/docs/troubleshooting)
- [Cloud Armor Troubleshooting](https://cloud.google.com/armor/docs/troubleshooting)
- [DefectDojo Documentation](https://docs.defectdojo.com/)
