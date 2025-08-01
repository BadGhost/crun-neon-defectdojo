# Cost Analysis

This document provides a comprehensive analysis of the costs associated with deploying DefectDojo on Google Cloud Platform using this Terraform configuration.

## Monthly Cost Breakdown

### Core Infrastructure Costs

#### 1. Global HTTPS Load Balancer
- **Base Cost**: $18.00/month
- **Forwarding Rules**: $18.00/month for first 5 rules
- **SSL Certificates**: $0.00 (Google-managed certificates are free)
- **Data Processing**: $0.008 per GB of data processed

**Total Load Balancer**: ~$18-25/month (depending on traffic)

#### 2. Cloud Armor
- **Security Policy**: $5.00/month per policy
- **Rules**: $1.00/month per rule (first 10 rules free)
- **Requests**: $0.75 per million requests

**Total Cloud Armor**: ~$5-8/month (low to moderate traffic)

#### 3. Cloud Run
- **Pay-per-use pricing** (scales to zero)
- **CPU**: $0.00002400 per vCPU-second
- **Memory**: $0.00000250 per GB-second
- **Requests**: $0.40 per million requests
- **Free tier**: 2 million requests, 400,000 GB-seconds, 200,000 vCPU-seconds per month

**Estimated Cloud Run Cost**: $0-10/month (depends on usage)

#### 4. Secret Manager
- **Secret Storage**: $0.06 per secret per month
- **Secret Access**: $0.03 per 10,000 operations
- **3 secrets**: Database URL, Secret Key, Admin Password

**Total Secret Manager**: ~$0.20/month

#### 5. Cloud Storage
- **Standard Storage**: $0.020 per GB per month
- **Operations**: Various pricing for read/write operations
- **Data Transfer**: Egress charges apply

**Estimated Storage**: $1-5/month (depending on file uploads)

### External Service Costs

#### Neon PostgreSQL Database
- **Free Tier**: 512 MB storage, shared compute
- **Paid Plans**: Start at $19/month for dedicated compute
- **This deployment**: Uses free tier = $0/month

### Total Monthly Cost Summary

| Component | Low Usage | Moderate Usage | High Usage |
|-----------|-----------|----------------|------------|
| Load Balancer | $18 | $22 | $30 |
| Cloud Armor | $5 | $7 | $12 |
| Cloud Run | $0 | $5 | $15 |
| Secret Manager | $0.20 | $0.25 | $0.40 |
| Cloud Storage | $1 | $3 | $8 |
| Neon Database | $0 | $0 | $0* |
| **TOTAL** | **$24.20** | **$37.25** | **$65.40** |

*Neon free tier has limitations; may need upgrade for production use

## Cost Optimization Strategies

### 1. Load Balancer Optimization

#### Current Configuration Benefits
- Global load balancer provides DDoS protection and global reach
- SSL certificate management included at no extra cost
- Automatic scaling and high availability

#### Alternative Options
```hcl
# Regional Load Balancer (Lower Cost)
# Trade-off: Regional availability only, no global distribution
# Savings: ~$15/month
# Note: Not implemented in this configuration due to security requirements
```

### 2. Cloud Run Optimization

#### Scale-to-Zero Configuration
```hcl
# Current configuration already optimized
scaling {
  min_instance_count = 0  # Scale to zero when not in use
  max_instance_count = 10 # Prevent runaway costs
}
```

#### Resource Right-Sizing
```hcl
# Consider reducing resources for low-traffic environments
resources {
  limits = {
    cpu    = "1"      # Reduced from 2
    memory = "2Gi"    # Reduced from 4Gi
  }
}
```

### 3. Cloud Armor Optimization

#### Rule Optimization
- Current configuration includes essential security rules
- Consider removing advanced rules for development environments
- Basic IP allowlist + rate limiting = $5/month minimum

### 4. Storage Optimization

#### Lifecycle Management
```hcl
# Current configuration includes lifecycle rules
lifecycle_rule {
  condition {
    age = 365  # Delete files after 1 year
  }
  action {
    type = "Delete"
  }
}
```

## Cost Monitoring and Alerts

### Set Up Budget Alerts

```bash
# Create a budget alert for the project
gcloud billing budgets create \
  --billing-account=BILLING_ACCOUNT_ID \
  --display-name="DefectDojo Monthly Budget" \
  --budget-amount=50 \
  --threshold-rule=percent=80,basis=CURRENT_SPEND \
  --threshold-rule=percent=100,basis=CURRENT_SPEND
```

### Enable Cost Monitoring

```bash
# Export billing data to BigQuery for analysis
gcloud logging sinks create defectdojo-billing-sink \
  bigquery.googleapis.com/projects/PROJECT_ID/datasets/billing_dataset \
  --log-filter='protoPayload.serviceName="compute.googleapis.com" OR protoPayload.serviceName="run.googleapis.com"'
```

### Terraform Cost Tracking

Add cost tracking labels to all resources:

```hcl
# Already implemented in modules
labels = {
  environment = var.environment
  application = "defectdojo"
  managed_by  = "terraform"
  cost_center = "security"
}
```

## Cost Comparison with Alternatives

### Traditional VM-Based Deployment

| Component | VM-Based | Cloud Run | Savings |
|-----------|----------|-----------|---------|
| Compute | $50-100/month | $0-15/month | $35-85/month |
| Load Balancer | $18/month | $18/month | $0 |
| Security | Manual setup | $5-8/month | Time savings |
| Management | High overhead | Fully managed | Operational savings |

### Managed Database Services

| Database Option | Monthly Cost | Trade-offs |
|----------------|--------------|------------|
| Neon Free Tier | $0 | 512MB limit, shared compute |
| Cloud SQL (micro) | $7-10 | Dedicated, managed |
| Cloud SQL (small) | $25-35 | Better performance |
| Self-managed on VM | $20-50 | Full control, more work |

## Production Cost Considerations

### Scaling Factors

1. **Traffic Volume**: Higher traffic increases Cloud Run and data transfer costs
2. **File Storage**: More uploads increase Cloud Storage costs
3. **Database Growth**: May require Neon paid plan or Cloud SQL migration
4. **Geographic Distribution**: Global load balancer provides value for international users

### Recommended Upgrades for Production

#### Database Upgrade
```hcl
# Consider upgrading to Cloud SQL for production
# Estimated additional cost: $25-50/month
resource "google_sql_database_instance" "defectdojo_db" {
  name             = "defectdojo-postgres"
  database_version = "POSTGRES_15"
  
  settings {
    tier = "db-f1-micro"  # $7-10/month
    # or
    tier = "db-g1-small"  # $25-35/month
  }
}
```

#### Enhanced Monitoring
```hcl
# Additional monitoring costs: $5-15/month
# - Advanced Cloud Monitoring metrics
# - Log retention beyond default
# - Custom dashboards and alerting
```

#### Backup and Disaster Recovery
```hcl
# Cloud Storage for backups: $2-10/month
# Cross-region replication: +50% storage costs
```

## Cost Reduction for Development/Testing

### Development Environment Optimization

```hcl
# Minimal Cloud Armor rules
variable "environment" {
  default = "dev"
}

# Reduced Cloud Run resources
container {
  resources {
    limits = {
      cpu    = "0.5"
      memory = "1Gi"
    }
  }
}

# Regional load balancer alternative
# (Requires architecture changes)
```

### Testing Environment

Consider using:
- Cloud Run with minimal resources
- Regional load balancer instead of global
- Basic Cloud Armor rules only
- Shorter data retention periods

**Estimated dev/test cost**: $10-20/month

## Return on Investment (ROI)

### Security Value
- **DDoS Protection**: Included with global load balancer
- **WAF Protection**: $5-8/month vs. $50-200/month for enterprise WAF
- **Managed SSL**: Free vs. $100-500/year for commercial certificates
- **Automated Security Updates**: Included with managed services

### Operational Savings
- **No Server Management**: Saves 10-20 hours/month of administration
- **Auto-scaling**: Prevents over-provisioning
- **Managed Database**: Reduces DBA overhead
- **Infrastructure as Code**: Ensures consistent deployments

### Total Cost of Ownership (TCO)

| Factor | Traditional Setup | This Solution | Annual Savings |
|--------|------------------|---------------|----------------|
| Infrastructure | $1,200-2,400 | $300-800 | $900-1,600 |
| Management Time | $6,000-12,000 | $1,000-2,000 | $5,000-10,000 |
| Security Tools | $1,200-6,000 | $60-100 | $1,100-5,900 |
| **Total TCO** | **$8,400-20,400** | **$1,360-2,900** | **$7,000-17,500** |

## Recommendations

### For Small Teams/Projects
- Use the current configuration as-is
- Monitor costs monthly
- Consider development environment optimizations

### For Medium Organizations
- Upgrade to Cloud SQL for better database performance
- Implement comprehensive monitoring
- Add backup and disaster recovery

### For Large Enterprises
- Consider multi-region deployment
- Implement advanced security features
- Add compliance monitoring and reporting

### Cost Management Best Practices

1. **Monitor Weekly**: Check costs and usage patterns
2. **Set Alerts**: Configure budget alerts at 80% and 100%
3. **Regular Reviews**: Monthly cost optimization reviews
4. **Right-Size Resources**: Adjust based on actual usage
5. **Use Labels**: Tag all resources for cost attribution
6. **Plan for Growth**: Understand scaling cost implications

## Conclusion

This DefectDojo deployment provides enterprise-grade security and scalability at a fraction of the cost of traditional infrastructure. The primary costs are the global load balancer and Cloud Armor, which provide significant security value. The serverless architecture ensures you only pay for what you use, making it cost-effective for both small teams and large organizations.

Key cost benefits:
- **Predictable monthly minimum**: ~$24/month
- **Scales with usage**: No over-provisioning
- **Managed services**: Reduced operational overhead
- **Built-in security**: Enterprise-grade protection included
