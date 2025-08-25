#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
LOCAL_PORT=${1:-2222}
REMOTE_PORT=${2:-22}
PID_FILE="$PROJECT_ROOT/.port-forward.pid"

echo "========================================="
echo "Starting SSM Port Forwarding"
echo "========================================="

# Check if already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "Warning: Port forwarding is already running (PID: $OLD_PID)"
        echo "To stop it, run: ./scripts/stop-forward.sh"
        exit 1
    else
        rm -f "$PID_FILE"
    fi
fi

# Check AWS CLI and Session Manager plugin
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed."
    exit 1
fi

if ! command -v session-manager-plugin &> /dev/null; then
    echo "Error: AWS Session Manager Plugin is not installed."
    echo "macOS: brew install --cask session-manager-plugin"
    exit 1
fi

# Get instance ID from terraform output
cd "$PROJECT_ROOT"
if [ ! -f "terraform.tfstate" ]; then
    echo "Error: No Terraform state found. Run ./scripts/start.sh first."
    exit 1
fi

INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null)
REGION=$(terraform output -raw region 2>/dev/null)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "null" ]; then
    echo "Error: Could not find instance ID."
    exit 1
fi

echo "Instance ID: $INSTANCE_ID"
echo "Region: $REGION"
echo "Local Port: $LOCAL_PORT"
echo "Remote Port: $REMOTE_PORT"
echo ""

# Check instance and SSM status
echo "Checking instance status..."
INSTANCE_STATE=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text 2>/dev/null)

if [ "$INSTANCE_STATE" != "running" ]; then
    echo "Error: Instance is not running (state: $INSTANCE_STATE)"
    exit 1
fi

# Check SSM agent
SSM_STATUS=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --region "$REGION" \
    --query 'InstanceInformationList[0].PingStatus' \
    --output text 2>/dev/null)

if [ "$SSM_STATUS" != "Online" ]; then
    echo "Error: SSM agent is not ready (status: $SSM_STATUS)"
    echo "Try again in a few seconds..."
    exit 1
fi

# Start port forwarding in background
echo "Starting port forwarding..."
echo "Local: localhost:$LOCAL_PORT -> Remote: localhost:$REMOTE_PORT"
echo ""

nohup aws ssm start-session \
    --target "$INSTANCE_ID" \
    --document-name AWS-StartPortForwardingSession \
    --parameters "{\"portNumber\":[\"$REMOTE_PORT\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}" \
    --region "$REGION" \
    > "$PROJECT_ROOT/.port-forward.log" 2>&1 &

PID=$!
echo $PID > "$PID_FILE"

# Wait a moment and check if it's running
sleep 2
if ! ps -p "$PID" > /dev/null 2>&1; then
    echo "Error: Failed to start port forwarding."
    echo "Check the log file: $PROJECT_ROOT/.port-forward.log"
    rm -f "$PID_FILE"
    exit 1
fi

echo "========================================="
echo "Port forwarding started successfully!"
echo "PID: $PID"
echo "========================================="
echo ""
echo "Connection examples:"
echo ""
echo "1. SSH through forwarded port:"
echo "   ssh -p $LOCAL_PORT ubuntu@localhost"
echo ""
echo "2. IntelliJ Gateway:"
echo "   Host: localhost"
echo "   Port: $LOCAL_PORT"
echo "   Username: ubuntu"
echo ""
echo "3. Custom port forwarding (e.g., for web app on port 3000):"
echo "   ./scripts/port-forward.sh 3000 3000"
echo ""
echo "To stop port forwarding:"
echo "   ./scripts/stop-forward.sh"
echo ""
echo "To check status:"
echo "   ps -p $PID"
echo ""

# Save forwarding info for other scripts
cat > "$PROJECT_ROOT/.port-forward.info" <<EOF
PID=$PID
LOCAL_PORT=$LOCAL_PORT
REMOTE_PORT=$REMOTE_PORT
INSTANCE_ID=$INSTANCE_ID
STARTED_AT=$(date)
EOF

echo "Port forwarding is running in background."
echo "Log file: $PROJECT_ROOT/.port-forward.log"