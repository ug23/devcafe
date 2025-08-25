#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "========================================="
echo "Starting AWS Spot Development Environment"
echo "========================================="

# Check for .env file
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo "Loading environment variables from .env file..."
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo "Warning: .env file not found. Using environment variables."
fi

# No required environment variables for SSM connection
# SSH key is now optional

# Optional but recommended variables check
OPTIONAL_VARS=(
    "TF_VAR_github_pat"
    "TF_VAR_github_username"
    "TF_VAR_github_repo_url"
)

MISSING_OPTIONAL=()
for var in "${OPTIONAL_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_OPTIONAL+=($var)
    fi
done

if [ ${#MISSING_OPTIONAL[@]} -ne 0 ]; then
    echo "Note: Some optional variables are not set:"
    printf ' - %s\n' "${MISSING_OPTIONAL[@]}"
    echo "Continuing without GitHub integration features."
    echo ""
fi

# Check AWS credentials
echo "Checking AWS credentials..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "Error: AWS credentials not configured."
    echo "Please configure AWS CLI with 'aws configure' or set AWS environment variables."
    exit 1
fi

# Initialize Terraform if needed
cd "$PROJECT_ROOT"
if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..."
    terraform init
fi

# Create terraform plan
echo "Creating Terraform plan..."
terraform plan -out=tfplan

# Ask for confirmation
echo ""
echo "========================================="
echo "Review the plan above. Do you want to proceed?"
read -p "Type 'yes' to continue: " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Aborted."
    rm -f tfplan
    exit 0
fi

# Apply Terraform
echo "Applying Terraform configuration..."
terraform apply tfplan

# Clean up plan file
rm -f tfplan

# Display connection information
echo ""
echo "========================================="
echo "Instance created successfully!"
echo "========================================="
echo ""
terraform output -json | jq -r '
    "SSH Command: " + .ssh_command.value,
    "Public IP: " + .public_ip.value,
    "Auto-terminate at: " + .auto_terminate_time.value
'

echo ""
echo "The instance will automatically terminate in ${TF_VAR_auto_terminate_hours:-4} hours."
echo "To extend, run: ./scripts/extend.sh [hours]"
echo ""
echo "To connect with JetBrains Gateway:"
terraform output -json jetbrains_gateway_config | jq -r 'if .value then
    "  Host: " + .value.host + "\n" +
    "  Port: " + (.value.port | tostring) + "\n" +
    "  Username: " + .value.username + "\n" +
    "  Key: " + .value.key_path
else empty end'