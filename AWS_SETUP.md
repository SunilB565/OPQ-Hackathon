# AWS Setup Guide for OPQ Hackathon Project

## Overview
This guide covers all the required AWS resources and configurations needed for the OPQ Hackathon project deployment.

## Prerequisites
- AWS Account with appropriate IAM permissions
- AWS CLI v2 installed and configured
- Terraform installed (v1.0+)
- IAM user with programmatic access

## Required AWS Resources

### 1. Identity & Access Management (IAM)

#### IAM Users
- **Jenkins CI User**: Programmatic access for Jenkins to deploy to AWS
  - Access Keys: Generate and store securely
  - Permissions: See policies below

#### IAM Roles
- **ECS Task Execution Role**
  - Name: `ecsTaskExecutionRole-hackathon-dev` and `ecsTaskExecutionRole-hackathon-prod`
  - Trust relationship: Allow ECS Tasks service
  - Policy: `AmazonECSTaskExecutionRolePolicy`

- **ECS Task Role** (if needed for application services)
  - Name: `ecsTaskRole-hackathon-dev`
  - Permissions: ECR pull, S3 access, CloudWatch logs

#### IAM Policies
Create a policy for Jenkins CI/CD user with the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:UpdateService",
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:DescribeTasks",
        "ecs:ListTasks",
        "ecs:RegisterTaskDefinition"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::*:role/ecsTaskExecutionRole*",
        "arn:aws:iam::*:role/ecsTaskRole*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": "*"
    }
  ]
}
```

---

### 2. Networking (VPC)

#### VPC Configuration (from terraform/dev/variables.tf)
- **VPC CIDR**: `10.180.0.0/16`
- **Public Subnets**: `10.180.3.0/24`, `10.180.4.0/24`
- **Private Subnets**: `10.180.1.0/24`, `10.180.2.0/24`
- **Availability Zones**: `us-east-1a`, `us-east-1b`

#### Subnets
- 2 Public subnets (for ALB/NAT Gateway)
- 2 Private subnets (for ECS tasks)

#### Internet Gateway
- Required for public subnet routing

#### NAT Gateway
- In public subnet for private subnet outbound traffic
- Elastic IP allocation required

#### Route Tables
- Public route table: Route 0.0.0.0/0 to Internet Gateway
- Private route table: Route 0.0.0.0/0 to NAT Gateway

#### Security Groups
1. **ALB Security Group**
   - Inbound: 80 (HTTP), 443 (HTTPS) from 0.0.0.0/0
   - Outbound: All traffic to ECS security group

2. **ECS Security Group**
   - Inbound: Port 3000 and 4000 from ALB security group
   - Outbound: All traffic 0.0.0.0/0

---

### 3. Container Registry (ECR)

#### Repositories
- **order-service**: Private repository for order service Docker images
- **storage-service**: Private repository for storage service Docker images

#### Configuration
- Image tag mutability: `MUTABLE`
- Scan on push: `ENABLED` (for Trivy scanning)
- Retention policy: Keep last 10 images

#### Lifecycle Policy (Optional)
Tag old untagged images for cleanup after 30 days

---

### 4. Container Orchestration (ECS)

#### ECS Cluster
- Name: `hackathon-cluster-dev`, `hackathon-cluster-prod`
- Launch type: FARGATE (serverless)
- Container Insights: ENABLED

#### Service Discovery
- **Namespace**: `hackathon.local` (private DNS)
- **Services**:
  - `order-service`
  - `storage-service`
- Type: DNS SRV records

#### Task Definitions
1. **order-service**
   - CPU: 256
   - Memory: 512 MB
   - Container port: 3000
   - Environment: `STORAGE_URL=http://storage-service.hackathon.local:4000`
   - Image: `{AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/order-service:latest`

2. **storage-service**
   - CPU: 256
   - Memory: 512 MB
   - Container port: 4000
   - Image: `{AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/storage-service:latest`

#### Services
- **order-service**: Running 2 tasks (desired count)
- **storage-service**: Running 2 tasks (desired count)
- Load balancer: ALB (Application Load Balancer)

#### Load Balancer (ALB)
- Name: `hackathon-alb-dev`
- Scheme: Internet-facing
- Subnets: Public subnets
- Security group: ALB security group
- Target groups:
  - `order-service-tg`: Port 3000
  - `storage-service-tg`: Port 4000

---

### 5. Logging & Monitoring

#### CloudWatch Log Groups
- `/ecs/order-service-dev`
- `/ecs/storage-service-dev`
- `/ecs/order-service-prod`
- `/ecs/storage-service-prod`

#### Log Retention
- Suggested: 30 days for dev, 90 days for prod

#### CloudWatch Alarms (Recommended)
- High CPU utilization (>80%)
- High memory utilization (>80%)
- Task failure rate
- ELB unhealthy targets

---

### 6. Storage (S3)

#### S3 Buckets
1. **Jenkins Artifacts Bucket**
   - Name: `{account-id}-hackathon-jenkins-artifacts`
   - Versioning: ENABLED
   - Encryption: AES-256 (default)
   - Access: Private

2. **Terraform State Bucket** (if not using local state)
   - Name: `{account-id}-hackathon-terraform-state`
   - Versioning: ENABLED
   - Encryption: AES-256
   - Block public access: ALL blocks enabled
   - MFA delete: ENABLED (recommended)

#### Lifecycle Policies
- Delete old versions after 90 days
- Transition to Glacier after 180 days

---

### 7. Optional: DNS (Route53)

#### Hosted Zone
- Domain: `hackathon.example.com` (replace with your domain)
- Type: Public/Private (based on your needs)

#### DNS Records
- **ALB**: A record pointing to ALB DNS name
- **Internal Services**: Private hosted zone for `hackathon.local`

---

## Setup Instructions

### Step 1: Create IAM User for Jenkins

```bash
# Create programmatic access user
aws iam create-user --user-name jenkins-ci

# Create access key
aws iam create-access-key --user-name jenkins-ci

# Attach policy (save the policy JSON to a file first)
aws iam put-user-policy --user-name jenkins-ci \
  --policy-name jenkins-deployment-policy \
  --policy-document file://jenkins-policy.json

# Save the Access Key ID and Secret Access Key securely
```

### Step 2: Create S3 Backend for Terraform (Optional)

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket {account-id}-hackathon-terraform-state \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket {account-id}-hackathon-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket {account-id}-hackathon-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket {account-id}-hackathon-terraform-state \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### Step 3: Initialize Terraform

```bash
cd terraform/dev

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan -out=tfplan

# Apply configuration
terraform apply tfplan
```

### Step 4: Configure Jenkins

1. **Access Jenkins**: http://your-jenkins-server:8080
2. **Unlock Jenkins**: Use initial admin password from server
3. **Install Plugins**:
   - AWS CodePipeline
   - Docker
   - Docker Commons
   - SonarQube Scanner
   - Email Extension
   - Blue Ocean

4. **Configure AWS Credentials in Jenkins**:
   - Go to Jenkins → Manage Jenkins → Manage Credentials
   - Add the Jenkins CI IAM user credentials
   - Secret text for: AWS_ACCOUNT_ID, AWS_REGION

5. **Configure SonarQube Integration**:
   - Install SonarQube Server or use SonarQube Cloud
   - Create project for each service
   - Configure sonar-scanner in Jenkins

6. **Create Pipeline Job**:
   - Pipeline Type: Pipeline script from SCM
   - SCM: Git (your repository URL)
   - Branch: */main
   - Script path: Jenkinsfile

### Step 5: Push Docker Images to ECR

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  {AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Build services
docker build -t order-service:latest services/order-service/
docker build -t storage-service:latest services/storage-service/

# Tag images
docker tag order-service:latest \
  {AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/order-service:latest

docker tag storage-service:latest \
  {AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/storage-service:latest

# Push to ECR
docker push {AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/order-service:latest
docker push {AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/storage-service:latest
```

### Step 6: Deploy via Terraform

```bash
cd terraform/dev

# Set variables
terraform apply -var='order_image={AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/order-service:latest' \
                 -var='storage_image={AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/storage-service:latest'

# Check ECS services
aws ecs list-services --cluster hackathon-cluster-dev
aws ecs describe-services --cluster hackathon-cluster-dev --services order-service storage-service
```

---

## Environment Variables for Jenkins

Set these in Jenkins job configuration or as Jenkins credentials:

```bash
AWS_ACCOUNT_ID = Your AWS Account ID
AWS_REGION = us-east-1
SONAR_HOST_URL = https://your-sonarqube-instance.com
SONAR_LOGIN = Your SonarQube token
DOCKER_REGISTRY = {AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
```

---

## Security Best Practices

1. **IAM Least Privilege**: Only grant necessary permissions
2. **Secrets Management**: Use AWS Secrets Manager or Parameter Store
3. **Network Security**: Keep databases in private subnets
4. **Encryption**: Enable encryption for data at rest and in transit
5. **Logging**: Enable CloudTrail for audit logging
6. **Image Scanning**: Enable ECR scan on push
7. **Backup**: Enable automated backups for databases
8. **Monitoring**: Set up CloudWatch alarms for critical metrics

---

## Cleanup

To remove all AWS resources:

```bash
# Scale down ECS services
aws ecs update-service --cluster hackathon-cluster-dev \
  --service order-service --desired-count 0
aws ecs update-service --cluster hackathon-cluster-dev \
  --service storage-service --desired-count 0

# Destroy Terraform resources
cd terraform/dev
terraform destroy

# Delete S3 buckets (if empty)
aws s3 rb s3://{account-id}-hackathon-terraform-state
aws s3 rb s3://{account-id}-hackathon-jenkins-artifacts

# Delete ECR repositories
aws ecr delete-repository --repository-name order-service --force
aws ecr delete-repository --repository-name storage-service --force

# Delete IAM user
aws iam delete-access-key --user-name jenkins-ci --access-key-id {ACCESS_KEY_ID}
aws iam delete-user-policy --user-name jenkins-ci --policy-name jenkins-deployment-policy
aws iam delete-user --user-name jenkins-ci
```

---

## Additional Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Jenkins Documentation](https://jenkins.io/doc/)
- [SonarQube Documentation](https://docs.sonarqube.org/)
- [Checkov Documentation](https://www.checkov.io/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
