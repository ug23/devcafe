output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_spot_instance_request.dev.spot_instance_id
}

output "ssm_connect_command" {
  description = "SSM command to connect to the instance"
  value       = "./scripts/connect.sh"
}

output "ssm_port_forward_command" {
  description = "SSM port forwarding command for IntelliJ Gateway"
  value       = "./scripts/port-forward.sh"
}

output "jetbrains_gateway_config" {
  description = "JetBrains Gateway connection information (after port forwarding)"
  value = {
    setup_command = "./scripts/port-forward.sh 2222 22"
    host          = "localhost"
    port          = 2222
    username      = "ubuntu"
    note          = "Run port-forward.sh first to establish connection"
  }
}

output "auto_terminate_time" {
  description = "Scheduled auto-termination time"
  value       = timeadd(timestamp(), "${var.auto_terminate_hours}h")
}

output "spot_request_id" {
  description = "Spot instance request ID"
  value       = aws_spot_instance_request.dev.id
}

output "spot_price" {
  description = "Actual spot price"
  value       = aws_spot_instance_request.dev.spot_bid_status
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}