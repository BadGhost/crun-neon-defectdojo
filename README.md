# DefectDojo on Google Cloud Run

This repository contains Terraform infrastructure code to deploy DefectDojo, a security vulnerability management platform, on Google Cloud Platform using Cloud Run with comprehensive security best practices.

## 🏗️ Architecture Overview

The deployment creates a secure, scalable, and cost-effective infrastructure that includes:

- **Cloud Run**: Serverless container hosting with scale-to-zero capability
- **Neon PostgreSQL**: Serverless PostgreSQL database (free tier)
- **Global HTTPS Load Balancer**: SSL termination and global distribution
- **Cloud Armor**: Web Application Firewall with IP-based access control
- **Secret Manager**: Secure storage and access of sensitive configuration
- **Cloud Storage**: Persistent file storage for DefectDojo media files
- **SSL/TLS**: Automatic SSL certificate management with sslip.io domain

## 📋 Prerequisites

Before deploying this infrastructure, ensure you have:

1. **Google Cloud Project**: A GCP project with billing enabled
2. **Terraform**: Version 1.0 or higher installed
3. **gcloud CLI**: Authenticated and configured for your project
4. **Neon Database**: A free PostgreSQL database from [Neon.tech](https://neon.tech)
5. **Source IP**: Your public IP address for Cloud Armor access control

### Required GCP APIs

Enable the following APIs in your GCP project:

```bash
gcloud services enable cloudrun.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable cloudbuild.googleapis.com
```

## 🚀 Quick Start

1. **Clone this repository**:
   ```bash
   git clone <repository-url>
   cd crun-neon-defectdojo
   ```

2. **Configure variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   ```

3. **Initialize and deploy**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Access DefectDojo**:
   - URL will be displayed in the terraform output
   - Retrieve admin password from Secret Manager

## 📖 Documentation

- [Architecture Details](docs/architecture.md)
- [Setup Guide](docs/setup.md)
- [Deployment Instructions](docs/deployment.md)
- [Cost Analysis](docs/cost-analysis.md)

## 🔒 Security Features

- **Network Security**: Cloud Armor with IP whitelisting
- **Secrets Management**: All sensitive data stored in Secret Manager
- **IAM**: Least-privilege service accounts
- **SSL/TLS**: Automatic certificate management
- **Rate Limiting**: Protection against abuse
- **WAF Rules**: Protection against common web attacks

## 💰 Cost Considerations

This deployment includes premium services with monthly costs:
- Global Load Balancer: ~$18-25/month
- Cloud Armor: ~$5-10/month
- SSL certificates: Included
- Cloud Run: Pay-per-use (scales to zero)
- Neon database: Free tier available

See [cost analysis](docs/cost-analysis.md) for detailed pricing information.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
- Check the [troubleshooting guide](docs/troubleshooting.md)
- Review the [DefectDojo documentation](https://docs.defectdojo.com/)
- Open an issue in this repository
