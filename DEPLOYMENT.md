# DefectDojo Deployment Guide

This guide provides step-by-step instructions for deploying DefectDojo on Google Cloud Platform using Terraform.

## Quick Deployment Summary

Your DefectDojo infrastructure consists of:
- **Cloud Run**: DefectDojo application with Redis sidecar
- **Load Balancer**: Global HTTPS load balancer with SSL certificate
- **Cloud Armor**: Security policy restricting access to your IP (175.143.2.117/32)
- **Secret Manager**: Secure storage for database credentials and secrets
- **Cloud Storage**: Persistent file storage
- **IAM**: Dedicated service account with minimal required permissions

## Pre-Deployment Checklist

✅ **Project Setup**: `your-defectdojo-project` is created and billing is enabled
✅ **Authentication**: You're authenticated with proper permissions  
✅ **Neon Database**: Database URL is configured in terraform.tfvars
✅ **IP Security**: Your IP (175.143.2.117/32) is configured for Cloud Armor
✅ **Terraform**: Configuration is validated

## Deployment Steps

### 1. Final Configuration Review

Review your configuration:
```bash
# Check your current settings
cat terraform.tfvars

# Validate one more time
terraform validate
```

### 2. Deploy Infrastructure

```bash
# Apply the configuration (this will take 15-20 minutes)
terraform apply

# When prompted, type 'yes' to confirm
```

**Expected Timeline:**
- **0-5 minutes**: API enablement and basic resources
- **5-10 minutes**: Cloud Run service and load balancer creation  
- **10-20 minutes**: SSL certificate provisioning (this is the longest step)

### 3. Monitor Deployment Progress

During deployment, you can monitor progress:

```bash
# In another terminal, check API enablement
gcloud services list --enabled --filter="name:(cloudrun OR compute OR secretmanager)"

# Check Cloud Run deployment
gcloud run services list --region=us-central1

# Monitor SSL certificate status
gcloud compute ssl-certificates list
```

### 4. Post-Deployment Verification

After `terraform apply` completes successfully:

```bash
# Get your application URL
terraform output defectdojo_url

# Check service status
gcloud run services describe defectdojo --region=us-central1 --format="value(status.url)"

# Verify load balancer health
gcloud compute backend-services get-health defectdojo-backend --global
```

## Expected Outputs

After successful deployment, you'll see:

```bash
defectdojo_url = "https://XX.XX.XX.XX.sslip.io"
load_balancer_ip = "XX.XX.XX.XX"
static_ip_address = "XX.XX.XX.XX"
storage_bucket_name = "your-defectdojo-project-defectdojo-files"
```

## First-Time Access

### 1. Wait for SSL Certificate

SSL certificate provisioning can take 10-60 minutes. Check status:

```bash
gcloud compute ssl-certificates describe defectdojo-ssl-cert --format="value(managed.status)"
```

Status should be `ACTIVE` before accessing via HTTPS.

### 2. Access DefectDojo

1. **Get your URL**: `terraform output defectdojo_url`
2. **Access application**: Open the URL in your browser
3. **Initial setup**: Follow DefectDojo's initial configuration wizard

### 3. Admin Credentials

Your admin password is auto-generated and stored securely:

```bash
# Get the admin password (this will only work from your IP)
gcloud secrets versions access latest --secret="defectdojo-admin-password"
```

**Default admin user**: `admin`

## Troubleshooting Common Issues

### SSL Certificate Stuck in PROVISIONING

**Symptoms**: Certificate status remains `PROVISIONING` for >60 minutes

**Solution**:
```bash
# Check DNS resolution
nslookup $(terraform output -raw defectdojo_url | sed 's|https://||')

# Force certificate recreation if needed
terraform taint module.load_balancer.google_compute_managed_ssl_certificate.defectdojo_cert
terraform apply
```

### Cloud Run Service Not Starting

**Symptoms**: Service shows as unhealthy or not ready

**Solutions**:
```bash
# Check service logs
gcloud run services logs read defectdojo --region=us-central1 --limit=50

# Common issues:
# 1. Database connection problems - verify Neon database is active
# 2. Memory issues - the service is configured with 4GB RAM
# 3. Container startup time - initial startup can take 2-3 minutes
```

### Access Denied (403 Errors)

**Symptoms**: All requests return 403 Forbidden

**Causes & Solutions**:
1. **Wrong IP**: Your public IP changed
   ```bash
   # Check current IP
   curl ifconfig.me
   
   # Update terraform.tfvars with new IP
   allowed_source_ip = "NEW.IP.ADDRESS/32"
   
   # Apply changes
   terraform apply
   ```

2. **Cloud Armor policy issues**:
   ```bash
   # Check policy status
   gcloud compute security-policies describe defectdojo-security-policy
   ```

### Database Connection Issues

**Symptoms**: DefectDojo shows database connection errors

**Solutions**:
```bash
# Test database connectivity from Cloud Shell
psql "$(gcloud secrets versions access latest --secret='defectdojo-neon-database-url')" -c "SELECT version();"

# Check if Neon database is active in the Neon dashboard
# Verify connection string format in terraform.tfvars
```

## Monitoring and Maintenance

### Health Checks

```bash
# Quick health check script
#!/bin/bash
echo "=== DefectDojo Health Check ==="

# 1. Check Cloud Run service
gcloud run services describe defectdojo --region=us-central1 --format="value(status.conditions[0].status)"

# 2. Check load balancer
gcloud compute backend-services get-health defectdojo-backend --global 2>/dev/null | grep HEALTHY

# 3. Check SSL certificate
gcloud compute ssl-certificates describe defectdojo-ssl-cert --format="value(managed.status)"

# 4. Test application response
curl -I $(terraform output -raw defectdojo_url) 2>/dev/null | head -1
```

### Log Monitoring

```bash
# Cloud Run logs
gcloud run services logs read defectdojo --region=us-central1 --limit=100

# Load balancer logs
gcloud logging read 'resource.type="http_load_balancer"' --limit=50 --format=json

# Security events
gcloud logging read 'resource.type="gce_backend_service" AND jsonPayload.statusDetails="denied_by_security_policy"' --limit=20
```

### Cost Monitoring

Key cost components:
- **Load Balancer**: ~$18/month base cost
- **Cloud Armor**: ~$1/policy + $1.50/rule (~$7/month total)
- **Cloud Run**: Pay-per-use (likely <$10/month for light usage)
- **Storage**: <$1/month for typical file storage
- **Secret Manager**: ~$0.06/secret/month

**Total estimated cost**: $35-45/month

### Backup Procedures

```bash
# Export Terraform state
terraform state pull > terraform-state-backup-$(date +%Y%m%d).json

# Backup critical secrets (store securely)
gcloud secrets versions access latest --secret="defectdojo-admin-password" > admin-password.txt
```

## Scaling Considerations

Your current configuration:
- **Max instances**: 10 (can handle significant load)
- **CPU**: 2 vCPUs per instance
- **Memory**: 4GB per instance
- **Auto-scaling**: Scales to zero when not in use

To increase capacity:
```bash
# Edit cloud_run module in terraform configuration
# Increase max_instance_count in modules/cloud_run/main.tf
# Apply changes with terraform apply
```

## Security Maintenance

### Regular Security Tasks

1. **Rotate secrets** (quarterly):
   ```bash
   # Generate new secret key
   terraform apply -replace="random_password.secret_key"
   ```

2. **Update IP whitelist** (as needed):
   ```bash
   # Update allowed_source_ip in terraform.tfvars
   # Apply with terraform apply
   ```

3. **Update container image** (monthly):
   ```bash
   # Update container_image in terraform.tfvars to specific version
   container_image = "defectdojo/defectdojo-django:2.25.1"
   terraform apply
   ```

4. **Review access logs** (weekly):
   ```bash
   gcloud logging read 'resource.type="http_load_balancer"' --freshness=7d
   ```

## Disaster Recovery

### Complete Infrastructure Recreation

If you need to recreate everything:

```bash
# 1. Backup current state
terraform state pull > backup-state.json

# 2. Destroy current infrastructure
terraform destroy

# 3. Recreate from scratch
terraform apply

# Note: Database data is preserved in Neon, but uploaded files in GCS will be lost
# unless you backup the storage bucket separately
```

### Partial Recovery

```bash
# Recreate specific components
terraform apply -target=module.cloud_run
terraform apply -target=module.load_balancer
```

## Support and Documentation

- **Terraform Configuration**: All code is in this repository
- **Google Cloud Documentation**: [Cloud Run](https://cloud.google.com/run/docs)
- **DefectDojo Documentation**: [Official Docs](https://defectdojo.readthedocs.io/)
- **Troubleshooting Guide**: See `docs/troubleshooting.md`

## Next Steps After Deployment

1. **Configure DefectDojo**: Set up users, teams, and security policies
2. **Integrate Tools**: Connect your security scanners and CI/CD pipelines
3. **Set Up Monitoring**: Configure alerts for application health
4. **Data Migration**: Import existing vulnerability data if applicable
5. **User Training**: Train your team on DefectDojo usage

---

**Estimated Total Deployment Time**: 20-30 minutes
**Monthly Operating Cost**: $35-45
**Security Level**: Enterprise-grade with IP restrictions and comprehensive monitoring
