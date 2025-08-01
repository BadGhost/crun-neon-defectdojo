#!/bin/bash

# Quick status check script for DefectDojo deployment
# Usage: ./check-status.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

echo "DefectDojo Deployment Status Check"
echo "=================================="
echo ""

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    print_error "Terraform not initialized. Run 'terraform init' first."
    exit 1
fi

# Check if deployment exists
if ! terraform show > /dev/null 2>&1; then
    print_error "No Terraform deployment found. Run 'terraform apply' first."
    exit 1
fi

# Get deployment outputs
echo "Getting deployment information..."
DEFECTDOJO_URL=$(terraform output -raw defectdojo_url 2>/dev/null || echo "")
STATIC_IP=$(terraform output -raw static_ip_address 2>/dev/null || echo "")

if [ -z "$DEFECTDOJO_URL" ] || [ -z "$STATIC_IP" ]; then
    print_error "Unable to get deployment outputs. Check Terraform state."
    exit 1
fi

echo "DefectDojo URL: $DEFECTDOJO_URL"
echo "Static IP: $STATIC_IP"
echo ""

# Check Cloud Run service
echo "Checking Cloud Run service..."
if gcloud run services describe defectdojo --region=us-central1 --format="value(status.conditions[0].status)" 2>/dev/null | grep -q "True"; then
    print_status "Cloud Run service is running"
else
    print_error "Cloud Run service is not ready"
fi

# Check SSL certificate
echo "Checking SSL certificate..."
SSL_STATUS=$(gcloud compute ssl-certificates describe defectdojo-ssl-cert --global --format="value(managed.status)" 2>/dev/null || echo "UNKNOWN")
case $SSL_STATUS in
    "ACTIVE")
        print_status "SSL certificate is active"
        ;;
    "PROVISIONING")
        print_warning "SSL certificate is still provisioning (this can take 10-20 minutes)"
        ;;
    *)
        print_error "SSL certificate status: $SSL_STATUS"
        ;;
esac

# Check load balancer backend health
echo "Checking load balancer health..."
if gcloud compute backend-services get-health defectdojo-backend --global >/dev/null 2>&1; then
    BACKEND_HEALTH=$(gcloud compute backend-services get-health defectdojo-backend --global --format="value(status[0].healthState)" 2>/dev/null || echo "UNKNOWN")
    case $BACKEND_HEALTH in
        "HEALTHY")
            print_status "Load balancer backend is healthy"
            ;;
        "UNHEALTHY")
            print_error "Load balancer backend is unhealthy"
            ;;
        *)
            print_warning "Backend health status: $BACKEND_HEALTH"
            ;;
    esac
else
    print_error "Unable to check backend health"
fi

# Test HTTP connectivity
echo "Testing HTTP connectivity..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$DEFECTDOJO_URL" 2>/dev/null || echo "000")
case $HTTP_STATUS in
    "200")
        print_status "HTTP connectivity successful"
        ;;
    "302"|"301")
        print_status "HTTP redirect successful (normal for DefectDojo)"
        ;;
    "403")
        print_warning "Access forbidden - check Cloud Armor IP allowlist"
        ;;
    "502"|"503")
        print_error "Server error - check Cloud Run service and logs"
        ;;
    "000")
        print_error "Connection failed - check DNS and network connectivity"
        ;;
    *)
        print_warning "Unexpected HTTP status: $HTTP_STATUS"
        ;;
esac

# Check secrets accessibility
echo "Checking Secret Manager access..."
if gcloud secrets versions access latest --secret="defectdojo-admin-password" >/dev/null 2>&1; then
    print_status "Admin password secret accessible"
else
    print_error "Cannot access admin password secret"
fi

echo ""
echo "Status check complete!"
echo ""

# Provide next steps
if [ "$SSL_STATUS" = "ACTIVE" ] && [ "$HTTP_STATUS" = "200" -o "$HTTP_STATUS" = "302" ]; then
    echo "🎉 Your DefectDojo deployment appears to be working!"
    echo ""
    echo "Next steps:"
    echo "1. Access DefectDojo at: $DEFECTDOJO_URL"
    echo "2. Get admin password: gcloud secrets versions access latest --secret=\"defectdojo-admin-password\""
    echo "3. Login with username 'admin' and the retrieved password"
elif [ "$SSL_STATUS" = "PROVISIONING" ]; then
    print_warning "Wait for SSL certificate to provision, then try again"
else
    print_warning "Some issues detected. Check the errors above and refer to docs/troubleshooting.md"
fi
