#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "========================================="
echo "Connecting to AWS Instance via SSM"
echo "========================================="

# Check AWS CLI and Session Manager plugin
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed."
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

if ! command -v session-manager-plugin &> /dev/null; then
    echo "Error: AWS Session Manager Plugin is not installed."
    echo ""
    echo "Installation instructions:"
    echo "macOS: brew install --cask session-manager-plugin"
    echo "Or visit: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"
    exit 1
fi

# Get instance ID from terraform output
cd "$PROJECT_ROOT"
if [ ! -f "terraform.tfstate" ]; then
    echo "Error: No Terraform state found. Is the environment running?"
    echo "Run ./scripts/start.sh first."
    exit 1
fi

INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null)
REGION=$(terraform output -raw region 2>/dev/null)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "null" ]; then
    echo "Error: Could not find instance ID. Is the environment running?"
    exit 1
fi

echo "Instance ID: $INSTANCE_ID"
echo "Region: $REGION"
echo ""

# Check instance status
echo "Checking instance status..."
INSTANCE_STATE=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text 2>/dev/null)

if [ "$INSTANCE_STATE" != "running" ]; then
    echo "Error: Instance is not running (current state: $INSTANCE_STATE)"
    exit 1
fi

# Check SSM agent status
echo "Checking SSM agent status..."
SSM_STATUS=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --region "$REGION" \
    --query 'InstanceInformationList[0].PingStatus' \
    --output text 2>/dev/null)

if [ -z "$SSM_STATUS" ] || [ "$SSM_STATUS" == "None" ]; then
    echo "Warning: SSM agent is not ready yet. Waiting..."
    
    # Wait for SSM agent to be ready (max 60 seconds)
    for i in {1..12}; do
        sleep 5
        SSM_STATUS=$(aws ssm describe-instance-information \
            --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
            --region "$REGION" \
            --query 'InstanceInformationList[0].PingStatus' \
            --output text 2>/dev/null)
        
        if [ "$SSM_STATUS" == "Online" ]; then
            echo "SSM agent is ready!"
            break
        fi
        
        echo "Waiting for SSM agent... ($i/12)"
    done
    
    if [ "$SSM_STATUS" != "Online" ]; then
        echo "Error: SSM agent is not responding. Please check the instance."
        exit 1
    fi
fi

# Start SSM session
echo ""
echo "========================================="
echo "Starting SSM session..."
echo "========================================="
echo ""
echo "Tips:"
echo "  - Use 'sudo su - ubuntu' to switch to ubuntu user"
echo "  - Type 'exit' to end the session"
echo ""

aws ssm start-session \
    --target "$INSTANCE_ID" \
    --region "$REGION"