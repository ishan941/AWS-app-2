# Jenkins CI/CD Setup Guide

This document provides comprehensive instructions for setting up and using Jenkins for CI/CD with your AWS App monorepo.

## 🏗️ Architecture Overview

Our Jenkins setup includes:

- **Jenkins Master**: Orchestrates builds and deployments
- **Docker Integration**: Builds and manages container images
- **Pipeline as Code**: Jenkinsfile-based CI/CD pipelines
- **Multi-environment Deployment**: Development, staging, and production
- **AWS Integration**: ECR, ECS, EC2 deployment support

## 📋 Prerequisites

Before setting up Jenkins, ensure you have:

- Docker and Docker Compose installed
- AWS CLI configured (for production deployments)
- Git repository access
- Environment variables configured

## 🚀 Quick Start

### 1. Start Jenkins

```bash
# Start Jenkins along with your application
docker-compose up -d jenkins

# Or start everything together
docker-compose up -d
```

### 2. Access Jenkins

- **URL**: http://localhost:8080
- **Default Admin Password**: `admin123` (change this immediately!)

### 3. Initial Setup

The Jenkins instance is pre-configured with:

- Essential plugins installed
- Node.js 20 configured
- Docker integration enabled
- Basic security settings

## 🔧 Configuration

### Environment Variables

Create a `.env` file in your project root:

```bash
# Jenkins Configuration
JENKINS_ADMIN_PASSWORD=your-secure-password

# Docker Registry (AWS ECR)
DOCKER_REGISTRY=your-account.dkr.ecr.us-east-1.amazonaws.com
AWS_REGION=us-east-1

# AWS Credentials (for production deployment)
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key

# Database Configuration
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your-db-password
POSTGRES_DB=aws_app

# Application Secrets
JWT_SECRET=your-jwt-secret-32-characters-minimum
SESSION_SECRET=your-session-secret-32-characters-min

# Deployment Configuration
DEPLOYMENT_TYPE=ecs  # or 'ec2'
EC2_HOST=your-ec2-instance-ip
EC2_USER=ubuntu
EC2_KEY_PATH=/path/to/your/key.pem
```

### AWS ECR Setup

1. Create ECR repositories:

```bash
aws ecr create-repository --repository-name aws-app-web
aws ecr create-repository --repository-name aws-app-backend
```

2. Get your registry URL:

```bash
aws ecr describe-repositories --query 'repositories[0].repositoryUri' --output text
```

## 📝 Pipeline Overview

### Automated Pipeline Stages

1. **Checkout**: Clone the repository
2. **Install Dependencies**: Install npm packages
3. **Lint & Test**: Run code quality checks and tests
4. **Build Applications**: Build React and NestJS apps
5. **Docker Build**: Create container images
6. **Security Scan**: Audit dependencies and scan images
7. **Integration Tests**: Run end-to-end tests
8. **Deploy**: Deploy to target environment

### Branch Strategy

- **`develop` branch**: Auto-deploy to development environment
- **`main` branch**: Manual approval required for production
- **Feature branches**: Run tests but don't deploy

## 🌍 Deployment Environments

### Development Environment

- **URL**: http://localhost:3000 (web), http://localhost:3001 (api)
- **Database**: Local PostgreSQL
- **Auto-deployment**: On `develop` branch commits
- **Docker Compose**: `docker-compose.dev.yml`

### Production Environment

- **Infrastructure**: AWS (ECS/EC2)
- **Database**: RDS PostgreSQL
- **Cache**: ElastiCache Redis
- **Manual approval**: Required for deployment
- **Image Registry**: AWS ECR

## 🔨 Manual Operations

### Build and Deploy Manually

```bash
# Build specific version
docker-compose exec jenkins jenkins-cli build aws-app-pipeline

# Deploy to development
./jenkins/scripts/deploy.sh development v1.0.0

# Deploy to production (after approval)
./jenkins/scripts/deploy.sh production v1.0.0

# Rollback if needed
./jenkins/scripts/deploy.sh rollback v0.9.0
```

### Managing Jenkins

```bash
# View Jenkins logs
docker-compose logs -f jenkins

# Restart Jenkins
docker-compose restart jenkins

# Access Jenkins CLI
docker-compose exec jenkins bash

# Backup Jenkins data
docker run --rm -v aws_production_based_ci_cd_jenkins_home:/data -v $(pwd):/backup alpine tar czf /backup/jenkins_backup.tar.gz -C /data .
```

## 🧪 Testing

### Running Tests Locally

```bash
# Unit tests
npm test

# Integration tests
docker-compose -f docker-compose.test.yml up --abort-on-container-exit

# Lint checks
npm run lint
```

### Test Configuration

Tests are configured in:

- `apps/web/package.json` (React tests)
- `apps/backend/package.json` (NestJS tests)
- `docker-compose.test.yml` (Integration tests)

## 🔐 Security

### Best Practices

1. **Change default passwords** immediately after setup
2. **Use strong JWT/Session secrets** in production
3. **Rotate AWS credentials** regularly
4. **Enable Docker image scanning** (Trivy/Snyk)
5. **Review dependency audits** before deployment

### Credentials Management

Jenkins credentials are managed through:

- Configuration as Code (CasC)
- Environment variables
- AWS IAM roles (recommended for production)

## 📊 Monitoring and Logs

### Application Health Checks

- **Backend**: `GET /api/health`
- **Database**: PostgreSQL connection check
- **Cache**: Redis ping check

### Log Access

```bash
# Application logs
docker-compose logs -f backend
docker-compose logs -f web

# Jenkins logs
docker-compose logs -f jenkins

# System logs
docker-compose logs --tail=100
```

## 🚨 Troubleshooting

### Common Issues

1. **Jenkins won't start**

   ```bash
   # Check Docker daemon
   docker ps

   # Check logs
   docker-compose logs jenkins

   # Restart with clean slate
   docker-compose down -v jenkins
   docker-compose up -d jenkins
   ```

2. **Build fails**

   ```bash
   # Check Node.js version
   docker-compose exec jenkins node --version

   # Check Docker access
   docker-compose exec jenkins docker ps

   # Review build logs in Jenkins UI
   ```

3. **Deployment fails**

   ```bash
   # Check AWS credentials
   docker-compose exec jenkins aws sts get-caller-identity

   # Verify ECR access
   docker-compose exec jenkins aws ecr describe-repositories

   # Test deployment script manually
   ./jenkins/scripts/deploy.sh development latest
   ```

### Performance Optimization

1. **Jenkins**: Increase memory if builds are slow
2. **Docker**: Use multi-stage builds and layer caching
3. **Tests**: Run tests in parallel where possible
4. **Images**: Use Alpine-based images for smaller size

## 🔄 Maintenance

### Regular Tasks

1. **Update Jenkins plugins** monthly
2. **Clean up old Docker images** weekly
3. **Review security audits** before each deployment
4. **Backup Jenkins configuration** weekly
5. **Monitor disk space** on Jenkins server

### Backup Strategy

```bash
# Backup Jenkins home
docker run --rm -v jenkins_home:/data -v $(pwd):/backup alpine tar czf /backup/jenkins_$(date +%Y%m%d).tar.gz -C /data .

# Backup database
docker-compose exec postgres pg_dump -U postgres aws_app > backup_$(date +%Y%m%d).sql
```

## 📚 Additional Resources

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [Node.js Best Practices](https://nodejs.org/en/docs/guides/)

## 🆘 Support

For issues and questions:

1. Check logs first: `docker-compose logs jenkins`
2. Review Jenkins UI build history
3. Consult this documentation
4. Check AWS service status if deployment issues
5. Review Docker daemon status for container issues

---

**Note**: This setup is configured for development and small-scale production use. For enterprise deployments, consider using Jenkins agents, Kubernetes, and advanced monitoring solutions.
