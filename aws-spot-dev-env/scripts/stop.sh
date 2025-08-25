#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "========================================="
echo "Stopping AWS Spot Development Environment"
echo "========================================="

# Check for .env file
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo "Loading environment variables from .env file..."
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Check if terraform state exists
cd "$PROJECT_ROOT"
if [ ! -f "terraform.tfstate" ]; then
    echo "No Terraform state found. Nothing to destroy."
    exit 0
fi

# Check AWS credentials
echo "Checking AWS credentials..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "Error: AWS credentials not configured."
    echo "Please configure AWS CLI with 'aws configure' or set AWS environment variables."
    exit 1
fi

# Show current resources
echo ""
echo "Current resources to be destroyed:"
terraform show -no-color | grep -E "^resource|^  id|^  Name" || true

# Ask for confirmation
echo ""
echo "========================================="
echo "WARNING: This will destroy all resources!"
echo "========================================="
read -p "Type 'destroy' to continue: " -r
echo ""

if [[ ! $REPLY == "destroy" ]]; then
    echo "Aborted."
    exit 0
fi

# Destroy resources
echo "Destroying resources..."
terraform destroy -auto-approve

# Clean up local files
echo "Cleaning up local files..."
rm -f lambda_terminate.zip
rm -f tfplan

echo ""
echo "========================================="
echo "All resources have been destroyed."
echo "========================================="