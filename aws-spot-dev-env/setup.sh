#!/bin/bash
set -e

# Variables from Terraform
GITHUB_PAT="${github_pat}"
GITHUB_USERNAME="${github_username}"
GITHUB_EMAIL="${github_email}"
GITHUB_REPO_URL="${github_repo_url}"
AUTO_TERMINATE_HOURS="${auto_terminate_hours}"
PROJECT_NAME="${project_name}"

# Logging
LOG_FILE="/var/log/setup.log"
exec 1> >(tee -a $LOG_FILE)
exec 2>&1

echo "========================================="
echo "Starting setup at $(date)"
echo "========================================="

# Update system
echo "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install basic tools
echo "Installing basic tools..."
sudo apt-get install -y \
    curl \
    wget \
    git \
    htop \
    ncdu \
    jq \
    build-essential \
    software-properties-common \
    ca-certificates \
    gnupg \
    lsb-release \
    zip \
    unzip \
    net-tools \
    vim \
    tmux \
    python3-pip

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu
rm get-docker.sh

# Install Docker Compose
echo "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name')
sudo curl -L "https://github.com/docker/compose/releases/download/$${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Configure Git if credentials provided
if [ -n "$GITHUB_PAT" ] && [ -n "$GITHUB_USERNAME" ]; then
    echo "Configuring Git credentials..."
    
    # Set git config
    sudo -u ubuntu git config --global user.name "$GITHUB_USERNAME"
    [ -n "$GITHUB_EMAIL" ] && sudo -u ubuntu git config --global user.email "$GITHUB_EMAIL"
    
    # Setup credential helper
    sudo -u ubuntu git config --global credential.helper store
    echo "https://$${GITHUB_USERNAME}:$${GITHUB_PAT}@github.com" | sudo -u ubuntu tee /home/ubuntu/.git-credentials > /dev/null
    chmod 600 /home/ubuntu/.git-credentials
    chown ubuntu:ubuntu /home/ubuntu/.git-credentials
fi

# Clone repository if URL provided
if [ -n "$GITHUB_REPO_URL" ]; then
    echo "Cloning repository: $GITHUB_REPO_URL"
    cd /home/ubuntu
    sudo -u ubuntu git clone "$GITHUB_REPO_URL" project || echo "Failed to clone repository"
fi

# JetBrains Remote Development setup
echo "Setting up for JetBrains Remote Development..."
sudo -u ubuntu mkdir -p /home/ubuntu/.cache/JetBrains
sudo -u ubuntu mkdir -p /home/ubuntu/.config/JetBrains
sudo -u ubuntu mkdir -p /home/ubuntu/.local/share/JetBrains

# Install required packages for JetBrains IDE backend
sudo apt-get install -y \
    libssl-dev \
    libffi-dev \
    python3-dev \
    python3-venv

# Setup auto-termination cron job (backup to Lambda)
echo "Setting up auto-termination backup cron job..."
cat > /usr/local/bin/check-termination.sh << 'EOF'
#!/bin/bash
TERMINATE_TIME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$(ec2-metadata --instance-id | cut -d ' ' -f 2)" "Name=key,Values=TerminateTime" --query 'Tags[0].Value' --output text --region $(ec2-metadata --availability-zone | cut -d ' ' -f 2 | sed 's/.$//' ) 2>/dev/null)

if [ -n "$TERMINATE_TIME" ]; then
    CURRENT_TIME=$(date -u +%s)
    TERMINATE_TIMESTAMP=$(date -d "$TERMINATE_TIME" +%s)
    
    if [ $CURRENT_TIME -ge $TERMINATE_TIMESTAMP ]; then
        logger "Auto-termination time reached. Shutting down..."
        sudo shutdown -h now
    fi
fi
EOF

chmod +x /usr/local/bin/check-termination.sh

# Add to cron (every 5 minutes)
echo "*/5 * * * * /usr/local/bin/check-termination.sh" | sudo crontab -

# Install AWS CLI v2 for the termination script
echo "Installing AWS CLI v2..."
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
cd -

# Install ec2-metadata
echo "Installing ec2-metadata..."
wget http://s3.amazonaws.com/ec2metadata/ec2-metadata
chmod +x ec2-metadata
sudo mv ec2-metadata /usr/local/bin/

# Create MOTD with setup information
cat > /etc/motd << EOF
========================================
   AWS Spot Development Environment
========================================
Project: $PROJECT_NAME
Auto-terminate in: $AUTO_TERMINATE_HOURS hours
Instance will terminate at: $(date -d "+$AUTO_TERMINATE_HOURS hours" '+%Y-%m-%d %H:%M:%S UTC')

To extend termination time:
  aws ec2 create-tags --resources \$(ec2-metadata --instance-id | cut -d ' ' -f 2) \\
    --tags Key=TerminateTime,Value=\$(date -u -d '+2 hours' --iso-8601=seconds) \\
    --region \$(ec2-metadata --availability-zone | cut -d ' ' -f 2 | sed 's/.\$//')

Docker version: \$(docker --version 2>/dev/null | cut -d ' ' -f3 | tr -d ',')
Docker Compose version: \$(docker-compose --version 2>/dev/null | cut -d ' ' -f4)
========================================
EOF

# Final message
echo "========================================="
echo "Setup completed at $(date)"
echo "========================================="

# Send notification (optional - requires SNS topic)
# aws sns publish --topic-arn "arn:aws:sns:region:account:topic" --message "Dev environment setup completed for $PROJECT_NAME"