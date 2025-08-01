# Deployment Guide

This guide covers the complete deployment process, from initial infrastructure provisioning to accessing your DefectDojo instance.

## Pre-Deployment Checklist

Before starting the deployment, ensure you have completed all steps in the [Setup Guide](setup.md):

- [ ] GCP project configured with required APIs enabled
- [ ] Terraform installed and authenticated
- [ ] Neon database created and connection string obtained
- [ ] `terraform.tfvars` file configured with your values
- [ ] Network access configured (IP address whitelisted)

## Deployment Process

### Step 1: Initialize Terraform

```bash
# Navigate to project directory
cd crun-neon-defectdojo

# Initialize Terraform
terraform init

# Expected output:
# Terraform has been successfully initialized!
```

### Step 2: Review Deployment Plan

```bash
# Generate and review the execution plan
terraform plan

# Review the plan carefully, ensuring:
# - Correct project ID and region
# - Proper resource naming
# - Expected resource count (approximately 25-30 resources)
```

### Step 3: Deploy Infrastructure

```bash
# Apply the Terraform configuration
terraform apply

# Review the plan one more time, then type 'yes' to confirm
# Deployment typically takes 10-15 minutes
```

### Step 4: Monitor Deployment Progress

The deployment process includes several phases:

1. **IAM and Secrets** (1-2 minutes)
   - Service account creation
   - Secret Manager secrets
   - IAM policy bindings

2. **Storage and Networking** (2-3 minutes)
   - Cloud Storage bucket
   - Global IP address reservation
   - Cloud Armor security policy

3. **Cloud Run Service** (3-5 minutes)
   - Container deployment
   - Service configuration
   - Health check setup

4. **Load Balancer** (5-10 minutes)
   - Backend service configuration
   - SSL certificate provisioning
   - Forwarding rules setup

**Note**: SSL certificate provisioning can take up to 20 minutes. The deployment will complete, but HTTPS access may not be immediately available.

## Post-Deployment Configuration

### Step 1: Retrieve Outputs

```bash
# Display all deployment outputs
terraform output

# Key outputs include:
# - defectdojo_url: Your DefectDojo access URL
# - static_ip_address: Load balancer IP
# - admin_password_secret_name: Secret containing admin password
```

### Step 2: Retrieve Admin Password

```bash
# Get the admin password from Secret Manager
gcloud secrets versions access latest --secret="defectdojo-admin-password"

# Or using the output variable
SECRET_NAME=$(terraform output -raw admin_password_secret_name)
gcloud secrets versions access latest --secret="$SECRET_NAME"
```

### Step 3: Wait for SSL Certificate

```bash
# Check SSL certificate status
gcloud compute ssl-certificates list

# Certificate status should show "ACTIVE"
# If "PROVISIONING", wait a few more minutes
```

### Step 4: Verify DNS Resolution

```bash
# Get your DefectDojo URL
DEFECTDOJO_URL=$(terraform output -raw defectdojo_url)
echo "DefectDojo URL: $DEFECTDOJO_URL"

# Test DNS resolution
nslookup $(echo $DEFECTDOJO_URL | sed 's|https://||')

# The IP should match your static IP address
```

## First Access

### Step 1: Access DefectDojo

1. Open your browser and navigate to the URL from terraform output
2. You may see a security warning initially while the SSL certificate provisions
3. If using HTTP initially, you'll be redirected to HTTPS

### Step 2: Initial Login

1. Username: `admin`
2. Password: Retrieved from Secret Manager (Step 2 above)
3. Complete the initial setup wizard

### Step 3: Initial Configuration

#### Update Admin Profile
1. Go to **Configuration** → **Users**
2. Edit the admin user
3. Update email address and personal information

#### Configure System Settings
1. Go to **Configuration** → **System Settings**
2. Update:
   - **Site URL**: Your DefectDojo URL
   - **Time Zone**: Your preferred timezone
   - **Email Configuration**: SMTP settings if needed

#### Create Additional Users
1. Go to **Configuration** → **Users**
2. Add users as needed
3. Assign appropriate roles and permissions

## Verification Steps

### Step 1: Health Checks

```bash
# Check Cloud Run service status
gcloud run services list --region=us-central1

# Check load balancer backend health
gcloud compute backend-services get-health defectdojo-backend --global
```

### Step 2: Security Verification

```bash
# Test access from allowed IP (should work)
curl -I https://YOUR_DEFECTDOJO_URL

# Test access from different IP (should be blocked)
# Use a proxy or different network to verify
```

### Step 3: Application Testing

1. **Login Functionality**: Verify admin login works
2. **Navigation**: Test main menu items
3. **File Upload**: Try uploading a test file
4. **Database Connection**: Check that data persists across sessions

## Troubleshooting Deployment Issues

### Common Issues and Solutions

#### 1. SSL Certificate Not Provisioning

**Symptoms**: HTTPS access fails, certificate shows "PROVISIONING"

**Solutions**:
```bash
# Check certificate status
gcloud compute ssl-certificates describe defectdojo-ssl-cert --global

# Verify domain DNS resolution
nslookup YOUR_IP_ADDRESS.sslip.io

# If stuck, delete and recreate certificate
terraform apply -replace="module.load_balancer.google_compute_managed_ssl_certificate.defectdojo_cert"
```

#### 2. Cloud Run Service Not Starting

**Symptoms**: Service shows as not ready, health checks failing

**Solutions**:
```bash
# Check Cloud Run logs
gcloud run services logs read defectdojo --region=us-central1

# Common issues:
# - Database connection problems
# - Missing environment variables
# - Container startup failures
```

#### 3. Load Balancer 502/503 Errors

**Symptoms**: Load balancer returns server errors

**Solutions**:
```bash
# Check backend service health
gcloud compute backend-services get-health defectdojo-backend --global

# Check Cloud Run service status
gcloud run services describe defectdojo --region=us-central1

# Verify NEG endpoints
gcloud compute network-endpoint-groups list
```

#### 4. Database Connection Issues

**Symptoms**: Application errors related to database connectivity

**Solutions**:
```bash
# Test database connection from Cloud Shell
gcloud secrets versions access latest --secret="defectdojo-neon-database-url"

# Test connection manually
psql "$(gcloud secrets versions access latest --secret='defectdojo-neon-database-url')" -c "SELECT 1;"
```

#### 5. Permission Errors

**Symptoms**: 403 errors, permission denied messages

**Solutions**:
```bash
# Check service account permissions
gcloud iam service-accounts get-iam-policy defectdojo-cloudrun@PROJECT_ID.iam.gserviceaccount.com

# Verify secret access
gcloud secrets get-iam-policy defectdojo-neon-database-url
```

### Debugging Commands

```bash
# Comprehensive status check
echo "=== Cloud Run Status ==="
gcloud run services list --region=us-central1

echo "=== Load Balancer Status ==="
gcloud compute forwarding-rules list --global

echo "=== SSL Certificate Status ==="
gcloud compute ssl-certificates list

echo "=== Cloud Armor Policy ==="
gcloud compute security-policies list

echo "=== Backend Health ==="
gcloud compute backend-services get-health defectdojo-backend --global

echo "=== Recent Logs ==="
gcloud run services logs read defectdojo --region=us-central1 --limit=50
```

## Rollback Procedures

### Emergency Rollback

If you need to quickly rollback the deployment:

```bash
# Destroy all resources
terraform destroy

# Confirm with 'yes' when prompted
# This will remove all infrastructure but preserve:
# - Neon database (external)
# - Cloud Storage data (if force_destroy = false)
```

### Partial Rollback

To rollback specific components:

```bash
# Rollback just the Cloud Run service
terraform apply -replace="module.cloud_run.google_cloud_run_v2_service.defectdojo"

# Rollback load balancer configuration
terraform apply -replace="module.load_balancer"
```

## Monitoring and Maintenance

### Set Up Monitoring

```bash
# Create basic monitoring dashboard
gcloud monitoring dashboards create --config-from-file=monitoring-dashboard.json
```

### Regular Maintenance Tasks

1. **Monitor Resource Usage**: Check Cloud Run metrics weekly
2. **Review Security Logs**: Check Cloud Armor logs for blocked requests
3. **Update Container Image**: Regularly update DefectDojo version
4. **Backup Verification**: Ensure Neon database backups are working
5. **Cost Monitoring**: Review monthly costs and optimize as needed

## Next Steps

After successful deployment:

1. Review the [Cost Analysis](cost-analysis.md) to understand ongoing expenses
2. Set up monitoring and alerting for production use
3. Configure DefectDojo for your security scanning workflows
4. Plan for regular maintenance and updates

## Support

If you encounter issues not covered in this guide:

1. Check the [Architecture Documentation](architecture.md) for system details
2. Review [Terraform logs](#debugging-commands) for specific error messages
3. Consult the [DefectDojo documentation](https://docs.defectdojo.com/) for application issues
4. Open an issue in this repository with detailed error information
