#!/bin/bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check if running as root (not recommended but script can work with sudo)
if [ "$EUID" -ne 0 ]; then 
    print_warning "This script should be run with sudo for system-wide installations"
    print_warning "Some commands will require sudo password"
fi

# Update system packages
print_header "Step 1: Updating System Packages"
sudo apt-get update -y
sudo apt-get upgrade -y
print_success "System packages updated"

# Install essential tools
print_header "Step 2: Installing Essential Tools"
sudo apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    jq
print_success "Essential tools installed"

# Install Java (required for Jenkins and SonarQube)
print_header "Step 3: Installing Java"
sudo apt-get install -y openjdk-11-jdk
java -version
print_success "Java 11 installed"

# Install Jenkins
print_header "Step 4: Installing Jenkins"
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins
print_success "Jenkins installed and started"
echo -e "${YELLOW}Jenkins initial admin password:${NC}"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""

# Install Docker
print_header "Step 5: Installing Docker"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl start docker
sudo systemctl enable docker
print_success "Docker installed"

# Add current user to docker group (requires re-login to take effect)
sudo usermod -aG docker $USER
print_warning "You may need to log out and log back in to use Docker without sudo"

# Install Docker Compose
print_header "Step 6: Installing Docker Compose"
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version
print_success "Docker Compose installed"

# Install Terraform
print_header "Step 7: Installing Terraform"
wget https://apt.releases.hashicorp.com/gpg
sudo apt-key add gpg
rm gpg
echo "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update -y
sudo apt-get install -y terraform
terraform --version
print_success "Terraform installed"

# Install AWS CLI v2
print_header "Step 8: Installing AWS CLI v2"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws/
aws --version
print_success "AWS CLI v2 installed"

# Install SonarQube Scanner
print_header "Step 9: Installing SonarQube Scanner"
wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.7.0.2747-linux.zip
unzip sonar-scanner-cli-4.7.0.2747-linux.zip
sudo mv sonar-scanner-4.7.0.2747-linux /opt/sonar-scanner
sudo ln -sf /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner
rm sonar-scanner-cli-4.7.0.2747-linux.zip
sonar-scanner --version
print_success "SonarQube Scanner installed"

# Install Checkov
print_header "Step 10: Installing Checkov"
sudo apt-get install -y python3-pip
sudo pip3 install checkov
checkov --version
print_success "Checkov installed"

# Install Trivy
print_header "Step 11: Installing Trivy"
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt-get update -y
sudo apt-get install -y trivy
trivy --version
print_success "Trivy installed"

# Install Node.js (for testing services locally)
print_header "Step 12: Installing Node.js"
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
node --version
npm --version
print_success "Node.js and npm installed"

# Install Git (if not already installed)
print_header "Step 13: Configuring Git"
git --version
print_success "Git is available"

echo ""
print_header "Installation Summary"
echo -e "${GREEN}All tools have been installed successfully!${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Configure AWS CLI:"
echo "   aws configure"
echo ""
echo "2. Access Jenkins:"
echo "   http://localhost:8080"
echo ""
echo "3. Configure SonarQube Scanner:"
echo "   - Set SONAR_HOST_URL environment variable"
echo "   - Set SONAR_LOGIN token"
echo ""
echo "4. Configure Jenkins git credentials for your repository"
echo ""
echo "5. Create Jenkins pipeline with the Jenkinsfile from this project"
echo ""
echo "6. See AWS_SETUP.md for required AWS resources setup"
echo ""
print_success "Installation complete!"
