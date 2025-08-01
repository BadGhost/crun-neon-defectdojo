# Architecture Overview

## System Architecture

This DefectDojo deployment on Google Cloud Platform follows a serverless, security-first architecture designed for scalability, cost-effectiveness, and security.

```
┌─────────────────────────────────────────────────────────────────┐
│                           Internet                              │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      │ HTTPS (443) / HTTP (80)
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                Global HTTPS Load Balancer                      │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐  │
│  │   SSL Cert      │ │   URL Map       │ │   Cloud Armor   │  │
│  │   (Managed)     │ │   (Routing)     │ │   (WAF/Security)│  │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘  │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      │ HTTP
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                    Cloud Run Service                           │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                 DefectDojo Container                    │  │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐  │  │
│  │  │   Django    │ │   Redis     │ │   Static Files  │  │  │
│  │  │   (Web App) │ │   (Cache)   │ │   (CSS/JS)      │  │  │
│  │  └─────────────┘ └─────────────┘ └─────────────────┘  │  │
│  └─────────────────────────────────────────────────────────┘  │
│                           │                                    │
│                           │ Service Account                    │
│                           │ (Least Privilege)                  │
└───────────────────────────┼────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Secret Manager│  │ Cloud Storage   │  │ Neon PostgreSQL │
│               │  │                 │  │                 │
│ • DB URL      │  │ • Media Files   │  │ • Application   │
│ • Secret Key  │  │ • Reports       │  │   Database      │
│ • Admin Pass  │  │ • Uploads       │  │ • Free Tier     │
└───────────────┘  └─────────────────┘  └─────────────────┘
```

## Component Details

### 1. Global HTTPS Load Balancer

**Purpose**: Provides global entry point with SSL termination and routing

**Components**:
- **Frontend**: Global IP address with HTTP(S) listeners
- **SSL Certificate**: Google-managed SSL certificate for sslip.io domain
- **URL Map**: Routes all traffic to Cloud Run backend
- **Cloud Armor**: Web Application Firewall with security policies

**Security Features**:
- Automatic SSL certificate provisioning and renewal
- HTTP to HTTPS redirect
- DDoS protection
- Geographic load balancing

### 2. Cloud Armor Security Policy

**Purpose**: Protects against web-based attacks and enforces access control

**Security Rules**:
1. **IP Allowlist**: Only specified source IP can access
2. **Rate Limiting**: Max 100 requests/minute per IP
3. **XSS Protection**: Blocks cross-site scripting attacks
4. **SQL Injection**: Prevents SQL injection attempts
5. **File Inclusion**: Blocks local/remote file inclusion
6. **Bot Protection**: Filters suspicious user agents

### 3. Cloud Run Service

**Purpose**: Hosts the DefectDojo application in a serverless container

**Configuration**:
- **Scaling**: 0-10 instances (scale to zero for cost efficiency)
- **Resources**: 2 CPU, 4GB memory per instance
- **Multi-container**: DefectDojo + Redis sidecar
- **Health Checks**: Startup and liveness probes

**Security Features**:
- Dedicated service account with minimal permissions
- Secrets injected as environment variables
- No direct internet access (behind load balancer)

### 4. Identity and Access Management (IAM)

**Service Account Permissions**:
- `secretmanager.secretAccessor` - Read application secrets
- `storage.objectAdmin` - Manage file uploads
- `monitoring.metricWriter` - Send application metrics
- `logging.logWriter` - Send application logs
- `cloudtrace.agent` - Distributed tracing

### 5. Secret Manager

**Purpose**: Secure storage and injection of sensitive configuration

**Secrets Stored**:
- Neon PostgreSQL connection URL
- Django secret key (auto-generated)
- Admin user password (auto-generated)

**Access Control**:
- Service account-specific access
- Audit logging for all secret access
- Version management for secret rotation

### 6. Cloud Storage

**Purpose**: Persistent storage for DefectDojo file uploads and media

**Configuration**:
- Regional bucket for cost optimization
- Versioning enabled for important files
- Lifecycle management (cleanup after 365 days)
- CORS enabled for web access

### 7. External Dependencies

#### Neon PostgreSQL Database
- **Type**: Serverless PostgreSQL (external service)
- **Tier**: Free tier (512MB storage, shared compute)
- **Connection**: SSL-required connection over internet
- **Backup**: Automated by Neon platform

#### sslip.io Domain Service
- **Purpose**: Provides wildcard DNS for any IP address
- **Format**: `{load-balancer-ip}.sslip.io`
- **SSL**: Automatic Google-managed certificate

## Security Architecture

### Defense in Depth

1. **Perimeter Security**: Cloud Armor at the edge
2. **Network Security**: Load balancer termination
3. **Application Security**: Container isolation
4. **Data Security**: Secret Manager and encryption
5. **Access Control**: IAM and service accounts

### Security Controls

| Layer | Control | Implementation |
|-------|---------|----------------|
| Edge | DDoS Protection | Google Cloud Load Balancer |
| Edge | WAF | Cloud Armor with OWASP rules |
| Edge | Access Control | IP allowlist in Cloud Armor |
| Network | SSL/TLS | Google-managed certificates |
| Network | Rate Limiting | Cloud Armor rate limiting |
| Application | Container Security | Cloud Run container isolation |
| Application | Secrets Management | Secret Manager integration |
| Data | Encryption at Rest | Google Cloud default encryption |
| Data | Encryption in Transit | TLS 1.2+ enforced |
| Access | Identity | Dedicated service accounts |
| Access | Least Privilege | Minimal IAM permissions |

## Scalability and Performance

### Automatic Scaling
- **Scale to Zero**: No cost when not in use
- **Auto-scaling**: Handles traffic spikes automatically
- **Global Distribution**: Load balancer with global reach
- **CDN Integration**: Static asset caching (optional)

### Performance Optimizations
- **Container Startup**: Optimized container image
- **Health Checks**: Fast startup and liveness detection
- **Connection Pooling**: Database connection efficiency
- **Caching**: Redis for session and application caching

## Disaster Recovery

### Backup Strategy
- **Database**: Automated by Neon (point-in-time recovery)
- **Files**: Cloud Storage with versioning
- **Configuration**: Infrastructure as Code (Terraform)
- **Secrets**: Secret Manager with version history

### Recovery Procedures
- **Infrastructure**: Terraform apply from source control
- **Database**: Neon platform backup restoration
- **Files**: Cloud Storage object recovery
- **Monitoring**: Cloud Logging and Monitoring integration

## Monitoring and Observability

### Logging
- **Application Logs**: Cloud Run → Cloud Logging
- **Access Logs**: Load Balancer → Cloud Logging
- **Security Logs**: Cloud Armor → Cloud Logging
- **Audit Logs**: IAM and resource access

### Metrics
- **Application**: Custom metrics via Cloud Monitoring
- **Infrastructure**: Cloud Run and Load Balancer metrics
- **Security**: Cloud Armor security metrics
- **Database**: Neon platform monitoring

### Alerting
- **Performance**: Response time and error rate alerts
- **Security**: Suspicious activity detection
- **Cost**: Budget alerts for unexpected charges
- **Availability**: Health check failure alerts
