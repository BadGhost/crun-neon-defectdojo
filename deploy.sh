#!/bin/bash

# DefectDojo Deployment Script
# This script automates the deployment process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        print_error "Google Cloud CLI is not installed"
        exit 1
    fi
    
    if [ ! -f "terraform.tfvars" ]; then
        print_error "terraform.tfvars file not found. Please copy from terraform.tfvars.example and configure."
        exit 1
    fi
    
    print_status "Prerequisites check passed"
}

# Initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    terraform init
}

# Plan deployment
plan_deployment() {
    print_status "Creating deployment plan..."
    terraform plan -out=tfplan
}

# Apply deployment
apply_deployment() {
    print_status "Applying deployment..."
    terraform apply tfplan
}

# Get outputs
get_outputs() {
    print_status "Deployment completed! Here are your connection details:"
    echo ""
    echo "DefectDojo URL: $(terraform output -raw defectdojo_url)"
    echo "Static IP: $(terraform output -raw static_ip_address)"
    echo ""
    print_status "To get the admin password, run:"
    echo "gcloud secrets versions access latest --secret=\"$(terraform output -raw admin_password_secret_name)\""
    echo ""
    print_warning "SSL certificate may take up to 20 minutes to provision."
    print_warning "If you see certificate errors initially, please wait and try again."
}

# Main execution
main() {
    echo "DefectDojo on Google Cloud Run - Deployment Script"
    echo "=================================================="
    
    check_prerequisites
    init_terraform
    plan_deployment
    
    echo ""
    print_warning "Review the plan above carefully."
    read -p "Do you want to proceed with deployment? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apply_deployment
        get_outputs
    else
        print_status "Deployment cancelled."
        exit 0
    fi
}

# Run main function
main "$@"
