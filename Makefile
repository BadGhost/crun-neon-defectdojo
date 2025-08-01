.PHONY: help init plan apply destroy status clean validate fmt check-prereqs

# Default target
help: ## Show this help message
	@echo "DefectDojo on Google Cloud Run - Terraform Commands"
	@echo "=================================================="
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check-prereqs: ## Check if all prerequisites are installed
	@echo "Checking prerequisites..."
	@command -v terraform >/dev/null 2>&1 || { echo "Error: terraform is not installed"; exit 1; }
	@command -v gcloud >/dev/null 2>&1 || { echo "Error: gcloud CLI is not installed"; exit 1; }
	@[ -f terraform.tfvars ] || { echo "Error: terraform.tfvars not found. Copy from terraform.tfvars.example"; exit 1; }
	@echo "✓ All prerequisites met"

init: check-prereqs ## Initialize Terraform
	terraform init

validate: ## Validate Terraform configuration
	terraform validate
	terraform fmt -check=true

fmt: ## Format Terraform code
	terraform fmt -recursive

plan: init ## Create deployment plan
	terraform plan -out=tfplan

apply: plan ## Apply the deployment
	terraform apply tfplan
	@echo ""
	@echo "Deployment complete! Run 'make status' to check the deployment."

destroy: ## Destroy all resources
	terraform destroy

status: ## Check deployment status
	@if [ -x "./check-status.sh" ]; then \
		chmod +x check-status.sh && ./check-status.sh; \
	else \
		echo "Status check script not found"; \
	fi

logs: ## Show Cloud Run service logs
	gcloud run services logs read defectdojo --region=us-central1 --limit=50

outputs: ## Show Terraform outputs
	terraform output

admin-password: ## Retrieve admin password from Secret Manager
	@echo "Admin password:"
	@gcloud secrets versions access latest --secret="defectdojo-admin-password" 2>/dev/null || echo "Unable to retrieve password. Check if deployment is complete."

url: ## Show DefectDojo URL
	@terraform output -raw defectdojo_url 2>/dev/null || echo "URL not available. Check if deployment is complete."

clean: ## Clean up temporary files
	rm -f tfplan
	rm -f terraform-state-backup.json

# Quick deployment
quick-deploy: init apply status ## Initialize, deploy, and check status

# Development helpers
dev-destroy: ## Quick destroy for development
	terraform destroy -auto-approve

dev-apply: ## Quick apply for development
	terraform apply -auto-approve
