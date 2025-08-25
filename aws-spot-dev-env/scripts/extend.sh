#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default extension time (hours)
EXTEND_HOURS=${1:-2}

echo "========================================="
echo "Extending Auto-Termination Time"
echo "========================================="

# Validate input
if ! [[ "$EXTEND_HOURS" =~ ^[0-9]+$ ]] || [ "$EXTEND_HOURS" -lt 1 ] || [ "$EXTEND_HOURS" -gt 24 ]; then
    echo "Error: Please provide a valid number of hours (1-24)"
    echo "Usage: $0 [hours]"
    echo "Example: $0 2  # Extend by 2 hours"
    exit 1
fi

# Check for .env file
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Check AWS credentials
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "Error: AWS credentials not configured."
    exit 1
fi

# Get instance ID from terraform output
cd "$PROJECT_ROOT"
if [ ! -f "terraform.tfstate" ]; then
    echo "Error: No Terraform state found. Is the environment running?"
    exit 1
fi

INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null)
REGION=$(terraform output -raw region 2>/dev/null)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "null" ]; then
    echo "Error: Could not find instance ID. Is the environment running?"
    exit 1
fi

# Calculate new termination time
NEW_TERMINATE_TIME=$(date -u -d "+$EXTEND_HOURS hours" --iso-8601=seconds)

echo "Instance ID: $INSTANCE_ID"
echo "Region: $REGION"
echo "Extending termination time by $EXTEND_HOURS hours"
echo "New termination time: $NEW_TERMINATE_TIME"

# Update the tag
aws ec2 create-tags \
    --resources "$INSTANCE_ID" \
    --tags "Key=TerminateTime,Value=$NEW_TERMINATE_TIME" \
    --region "$REGION"

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "Success! Termination time extended."
    echo "Instance will now terminate at: $NEW_TERMINATE_TIME"
    echo "========================================="
else
    echo "Error: Failed to update termination time."
    exit 1
fi

# Optional: Show current tags
echo ""
echo "Current instance tags:"
aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$INSTANCE_ID" \
    --region "$REGION" \
    --output table