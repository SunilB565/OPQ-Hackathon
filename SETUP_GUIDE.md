# Complete Setup Guide for OPQ Hackathon Project

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Infrastructure Setup](#infrastructure-setup)
3. [Tool Installation](#tool-installation)
4. [Configuration](#configuration)
5. [Deployment](#deployment)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Hardware Requirements (Minimum for Development)
- **Ubuntu Server**: 18.04 LTS or newer (22.04 LTS recommended)
- **CPU**: 4 cores
- **RAM**: 8 GB minimum (16 GB recommended)
- **Disk**: 50 GB free space
- **Network**: Stable internet connection with ports:
  - 8080 (Jenkins)
  - 4000 (Storage Service)
  - 3000 (Order Service)
  - 9000 (SonarQube, if local)

### AWS Account
- Valid AWS account
- IAM user with programmatic access
- Appropriate IAM permissions (see AWS_SETUP.md)
- Recommended region: `us-east-1`

### Local Machine Prerequisites
- Git installed
- SSH key pair for Jenkins/Ubuntu server access

---

## Infrastructure Setup

### Option 1: Local Ubuntu Machine/Server

1. **Fresh Ubuntu 22.04 LTS Installation**
   ```bash
   # Update system
   sudo apt-get update && sudo apt-get upgrade -y
   
   # Create project directory
   mkdir -p ~/projects
   cd ~/projects
   
   # Clone the repository
   git clone <your-repo-url>
   cd OPQ-Hackathon
   ```

2. **Run Installation Script**
   ```bash
   # Make script executable
   chmod +x install.sh
   
   # Run with sudo
   sudo ./install.sh
   ```

### Option 2: AWS EC2 Instance

```bash
# Launch EC2 instance (t3.large recommended)
# - Ubuntu 22.04 LTS AMI
# - 50 GB EBS volume
# - Security group with ports 8080, 3000, 4000 open

# Connect to instance
ssh -i your-key.pem ubuntu@your-instance-ip

# Run installation script
chmod +x install.sh
sudo ./install.sh
```

### Option 3: Docker Compose (All-in-One)

Create `docker-compose.yml` for complete stack:
```yaml
version: '3.8'

services:
  jenkins:
    image: jenkins/jenkins:latest
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false

  sonarqube:
    image: sonarqube:lts
    ports:
      - "9000:9000"
    environment:
      - SONAR_JDBC_URL=jdbc:postgresql://postgres:5432/sonar
      - SONAR_JDBC_USERNAME=sonar
      - SONAR_JDBC_PASSWORD=sonar
    depends_on:
      - postgres

  postgres:
    image: postgres:14
    environment:
      - POSTGRES_DB=sonar
      - POSTGRES_USER=sonar
      - POSTGRES_PASSWORD=sonar
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  jenkins_home:
  postgres_data:
```

---

## Tool Installation

### Automated Installation

The `install.sh` script installs all required tools. For manual installation, follow the steps below.

### Manual Installation Steps

#### 1. Java (Required for Jenkins & SonarQube)
```bash
sudo apt-get install -y openjdk-11-jdk
java -version
```

#### 2. Jenkins
```bash
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
sudo apt-get install -y jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

#### 3. Docker & Docker Compose
```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER

# Verify
docker --version
docker-compose --version
```

#### 4. Terraform
```bash
wget https://apt.releases.hashicorp.com/gpg
sudo apt-key add gpg
echo "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update
sudo apt-get install -y terraform
terraform --version
```

#### 5. AWS CLI v2
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

#### 6. SonarQube Scanner
```bash
wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.7.0.2747-linux.zip
unzip sonar-scanner-cli-4.7.0.2747-linux.zip
sudo mv sonar-scanner-4.7.0.2747-linux /opt/sonar-scanner
sudo ln -sf /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner
sonar-scanner --version
```

#### 7. Checkov
```bash
sudo apt-get install -y python3-pip
sudo pip3 install checkov
checkov --version
```

#### 8. Trivy
```bash
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy
trivy --version
```

#### 9. Node.js (for local testing)
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
node --version
npm --version
```

---

## Configuration

### 1. AWS CLI Configuration

```bash
aws configure

# Enter:
# - AWS Access Key ID: <your-key>
# - AWS Secret Access Key: <your-secret>
# - Default region: us-east-1
# - Default output format: json
```

### 2. Jenkins Configuration

#### Initial Setup
1. Access Jenkins: http://localhost:8080
2. Unlock with initial admin password
3. Install suggested plugins
4. Create first admin user

#### Install Additional Plugins
1. Go to **Manage Jenkins** → **Manage Plugins**
2. Install:
   - AWS CodePipeline
   - Docker Pipeline
   - SonarQube Scanner
   - Email Extension Plugin
   - Blue Ocean
   - Git

#### Configure Credentials
1. **Manage Jenkins** → **Manage Credentials**
2. Add AWS credentials:
   - Kind: AWS Credentials
   - Access Key ID: (from IAM user)
   - Secret Access Key: (from IAM user)

3. Add Git credentials:
   - Kind: Username with password / SSH Key
   - Use your GitHub/GitLab credentials

#### System Configuration
1. **Manage Jenkins** → **Configure System**
2. **Email Notification**:
   - SMTP server: `smtp.gmail.com`
   - SMTP port: `587`
   - Enable STARTTLS
   - Set sender email

3. **SonarQube Servers**:
   - Name: SonarQube
   - Server URL: http://your-sonarqube:9000
   - Server authentication token: (create in SonarQube)

### 3. SonarQube Configuration

#### SonarQube Server Installation (On-Premise)
```bash
# Option 1: Docker
docker run -d --name sonarqube \
  -p 9000:9000 \
  -e sonar.jdbc.url=jdbc:postgresql://postgres:5432/sonar \
  -e sonar.jdbc.username=sonar \
  -e sonar.jdbc.password=sonar \
  sonarqube:lts

# Option 2: SonarQube Cloud (Recommended)
# Sign up at https://sonarcloud.io
# Create organization and project
```

#### Project Setup in SonarQube
1. Create new project in SonarQube
2. Generate Project Token:
   - **My Account** → **Security** → **Generate Token**
3. Store token securely in Jenkins

#### Configure sonar-project.properties
Already in place for both services. Update:
```properties
sonar.projectKey=order-service
sonar.projectName=Order Service
sonar.sources=src
sonar.tests=tests
sonar.sourceEncoding=UTF-8
```

### 4. Git Configuration

```bash
# Set git user (if not already configured)
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Add SSH key (if using SSH)
ssh-keygen -t rsa -b 4096 -C "your.email@example.com"
# Add public key to GitHub/GitLab settings
```

### 5. Environment Variables

Create `.env` file in project root:
```bash
# AWS
AWS_ACCOUNT_ID=123456789012
AWS_REGION=us-east-1
AWS_ECR_REGISTRY=123456789012.dkr.ecr.us-east-1.amazonaws.com

# Jenkins
JENKINS_USER=admin
JENKINS_URL=http://localhost:8080

# SonarQube
SONAR_HOST_URL=http://localhost:9000
SONAR_LOGIN=<your-token>

# Applications
ORDER_SERVICE_PORT=3000
STORAGE_SERVICE_PORT=4000
```

---

## Deployment

### Step 1: Create Jenkins Pipeline

```groovy
// This is in Jenkinsfile already
pipeline {
  agent any
  
  environment {
    AWS_ACCOUNT_ID = credentials('aws_account_id')
    AWS_REGION = 'us-east-1'
  }
  
  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }
    
    stage('Build & Test') {
      steps {
        // Build and test steps
      }
    }
    
    stage('Security Scans') {
      parallel {
        stage('Checkov') {
          steps {
            sh './scripts/checkov_scan.sh'
          }
        }
        stage('Trivy') {
          steps {
            sh './scripts/trivy_scan.sh'
          }
        }
        stage('SonarQube') {
          steps {
            // SonarQube scanning
          }
        }
      }
    }
    
    stage('Build Docker Images') {
      steps {
        // Docker build
      }
    }
    
    stage('Deploy') {
      steps {
        // AWS ECS deployment via Terraform
      }
    }
  }
}
```

### Step 2: Create Jenkins Job

1. **New Item** → **Pipeline**
2. **Pipeline** section:
   - Definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: Your git repo
   - Branch: */main
   - Script path: Jenkinsfile

### Step 3: Test Pipeline

```bash
# Manually build
cd /Users/sunilb/Desktop/OPQ-Hackathon

# Test Node services
cd services/order-service
npm ci
npm test

cd ../storage-service
npm ci
npm test

# Test Terraform
cd terraform/dev
terraform init
terraform validate
terraform plan
```

### Step 4: Deploy to AWS

```bash
# Set AWS credentials
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret

# Deploy via Terraform
cd terraform/dev
terraform apply \
  -var='order_image=<ECR_IMAGE_ORDER>' \
  -var='storage_image=<ECR_IMAGE_STORAGE>'

# Get ALB DNS
terraform output alb_dns_name
```

---

## Troubleshooting

### Jenkins Issues

**Problem**: Jenkins won't start
```bash
# Check logs
sudo tail -f /var/log/jenkins/jenkins.log

# Check Java installation
java -version

# Restart Jenkins
sudo systemctl restart jenkins
```

**Problem**: Docker plugin not working
```bash
# Verify Docker daemon
sudo docker ps

# Add Jenkins user to docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### Docker Issues

**Problem**: Cannot push to ECR
```bash
# Login again
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  {AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Check image tag
docker images | grep order-service
```

### Terraform Issues

**Problem**: State lock
```bash
# Force unlock
terraform force-unlock <LOCK_ID>

# Or use local state initially
terraform state list
```

**Problem**: Missing variables
```bash
# Create terraform.tfvars
cat > terraform.tfvars << EOF
order_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/order-service:latest"
storage_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/storage-service:latest"
EOF
```

### Port Already in Use

```bash
# Find process using port
sudo lsof -i :8080

# Kill process
sudo kill -9 <PID>

# Or change port in Jenkins config
sudo nano /etc/default/jenkins
# Change HTTP_PORT=8080 to HTTP_PORT=8081
```

### AWS Credential Issues

```bash
# Verify credentials
aws sts get-caller-identity

# Check AWS config
cat ~/.aws/config
cat ~/.aws/credentials

# Reconfigure
aws configure
```

---

## Verification Checklist

- [ ] Ubuntu system updated and patched
- [ ] Java 11 installed and working
- [ ] Jenkins running on port 8080
- [ ] Docker installed and user in docker group
- [ ] Docker Compose installed
- [ ] Terraform installed and working
- [ ] AWS CLI configured with valid credentials
- [ ] SonarQube Scanner installed
- [ ] Checkov installed and working
- [ ] Trivy installed and working
- [ ] Node.js and npm installed
- [ ] Jenkins plugins installed
- [ ] AWS IAM user created for CI/CD
- [ ] ECR repositories created
- [ ] ECS cluster created via Terraform
- [ ] Pipeline job created in Jenkins
- [ ] Git credentials configured in Jenkins
- [ ] AWS credentials configured in Jenkins
- [ ] SonarQube project created and token generated

---

## Next Steps

1. **Configure CI/CD**: Set up Jenkins to trigger on git push
2. **Set up Email Notifications**: Configure Jenkins email alerts
3. **Implement Monitoring**: Set up CloudWatch alarms in AWS
4. **Backup Strategy**: Implement automated backups
5. **Documentation**: Update team documentation
6. **Training**: Train team on tools and workflows

---

## Support & Resources

- **Jenkins Documentation**: https://jenkins.io/doc/
- **Docker Documentation**: https://docs.docker.com/
- **Terraform Documentation**: https://www.terraform.io/docs/
- **AWS Documentation**: https://docs.aws.amazon.com/
- **SonarQube Documentation**: https://docs.sonarqube.org/
- **Checkov Documentation**: https://www.checkov.io/
- **Trivy Documentation**: https://aquasecurity.github.io/trivy/
