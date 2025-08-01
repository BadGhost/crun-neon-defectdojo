# Setup Guide

This guide walks you through the complete setup process for deploying DefectDojo on Google Cloud Platform.

## Prerequisites

### 1. Google Cloud Platform Setup

#### Create a GCP Project
```bash
# Create new project (replace with your preferred project ID)
gcloud projects create your-defectdojo-project --name="DefectDojo Security Platform"

# Set as default project
gcloud config set project your-defectdojo-project

# Link billing account (required for Cloud Run)
gcloud billing projects link your-defectdojo-project --billing-account=YOUR_BILLING_ACCOUNT_ID
```

#### Enable Required APIs
```bash
# Enable all required Google Cloud APIs
gcloud services enable cloudrun.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable certificatemanager.googleapis.com
gcloud services enable networkservices.googleapis.com
```

### 2. Install Required Tools

#### Terraform Installation
```bash
# On Windows (using Chocolatey)
choco install terraform

# On macOS (using Homebrew)
brew install terraform

# On Linux (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

#### Google Cloud CLI
```bash
# Install gcloud CLI - follow official instructions at:
# https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth login
gcloud auth application-default login

# Verify installation
gcloud --version
terraform --version
```

### 3. Neon Database Setup

#### Create Neon Account and Database
1. Visit [Neon.tech](https://neon.tech) and create a free account
2. Create a new project/database
3. Note down the connection string (format: `postgresql://username:password@host/database?sslmode=require`)

#### Verify Database Connection
```bash
# Test connection (replace with your actual connection string)
psql "postgresql://username:password@host/database?sslmode=require" -c "SELECT version();"
```

### 4. Network Configuration

#### Find Your Public IP Address
```bash
# Find your current public IP
curl ifconfig.me
# Or use
curl ipinfo.io/ip
```

**Important**: You'll need this IP address in CIDR notation (e.g., `203.0.113.42/32`) for the Cloud Armor security policy.

### 5. Project Configuration

#### Clone Repository
```bash
git clone <repository-url>
cd crun-neon-defectdojo
```

#### Configure Terraform Variables
```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your specific values
nano terraform.tfvars  # or use your preferred editor
```

#### terraform.tfvars Configuration
```hcl
# Required variables
project_id          = "your-defectdojo-project"
neon_database_url   = "postgresql://username:password@host/database?sslmode=require"
allowed_source_ip   = "203.0.113.42/32"  # Your public IP in CIDR format

# Optional variables (defaults shown)
region              = "us-central1"
environment         = "prod"
container_image     = "defectdojo/defectdojo-django:latest"
```

### 6. IAM Permissions

#### Required Permissions
Ensure your user account has the following IAM roles:
- `roles/owner` or
- `roles/editor` plus `roles/securityadmin`

#### Service Account Creation (Optional)
For production environments, consider using a dedicated service account:

```bash
# Create service account for Terraform
gcloud iam service-accounts create terraform-defectdojo \
    --display-name="Terraform DefectDojo Service Account"

# Grant necessary permissions
gcloud projects add-iam-policy-binding your-defectdojo-project \
    --member="serviceAccount:terraform-defectdojo@your-defectdojo-project.iam.gserviceaccount.com" \
    --role="roles/editor"

gcloud projects add-iam-policy-binding your-defectdojo-project \
    --member="serviceAccount:terraform-defectdojo@your-defectdojo-project.iam.gserviceaccount.com" \
    --role="roles/securityadmin"

# Download key file
gcloud iam service-accounts keys create terraform-key.json \
    --iam-account=terraform-defectdojo@your-defectdojo-project.iam.gserviceaccount.com

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/terraform-key.json"
```

## Validation Steps

### 1. Terraform Validation
```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment (dry run)
terraform plan
```

### 2. Prerequisites Checklist

Before proceeding to deployment, verify:

- [ ] GCP project created and billing enabled
- [ ] All required APIs enabled
- [ ] Terraform and gcloud CLI installed and authenticated
- [ ] Neon database created and connection string obtained
- [ ] Public IP address identified and formatted as CIDR
- [ ] terraform.tfvars file configured with correct values
- [ ] Terraform validation passes without errors

### 3. Resource Quotas

Check your project quotas for the following resources:

```bash
# Check compute quotas
gcloud compute project-info describe --project=your-defectdojo-project

# Key quotas to verify:
# - Global backend services: At least 1
# - Global forwarding rules: At least 2
# - SSL certificates: At least 1
# - Security policies: At least 1
# - Static IP addresses: At least 1
```

If you encounter quota issues, request increases through the GCP Console.

## Troubleshooting Common Setup Issues

### API Not Enabled Error
```bash
# If you get API not enabled errors, run:
gcloud services enable [API_NAME]

# Example:
gcloud services enable cloudrun.googleapis.com
```

### Authentication Issues
```bash
# Re-authenticate if needed
gcloud auth login
gcloud auth application-default login

# Verify current authentication
gcloud auth list
```

### Permission Errors
```bash
# Check current user permissions
gcloud projects get-iam-policy your-defectdojo-project

# If using service account, verify key file path
echo $GOOGLE_APPLICATION_CREDENTIALS
```

### Terraform State Issues
```bash
# If Terraform state gets corrupted
terraform init -reconfigure

# Force unlock if state is locked
terraform force-unlock LOCK_ID
```

### Network Connectivity
```bash
# Test Neon database connectivity
psql "YOUR_NEON_CONNECTION_STRING" -c "SELECT 1;"

# Test internet connectivity
curl -I https://google.com
```

## Security Considerations During Setup

### 1. Credential Management
- Never commit `terraform.tfvars` to version control
- Use strong, unique passwords for all accounts
- Enable 2FA on Google Cloud and Neon accounts
- Regularly rotate access keys and passwords

### 2. Network Security
- Use your actual public IP, not a placeholder
- Consider using a VPN if your IP changes frequently
- Restrict access to the minimum required IP range

### 3. Project Isolation
- Use a dedicated GCP project for DefectDojo
- Avoid mixing with other production workloads
- Implement proper resource tagging and labeling

## Next Steps

Once setup is complete, proceed to the [Deployment Guide](deployment.md) to deploy your DefectDojo infrastructure.
