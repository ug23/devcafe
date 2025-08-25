output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_spot_instance_request.dev.spot_instance_id
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = aws_spot_instance_request.dev.public_ip
}

output "public_dns" {
  description = "Public DNS name of the instance"
  value       = aws_spot_instance_request.dev.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${aws_spot_instance_request.dev.public_ip}"
}

output "jetbrains_gateway_config" {
  description = "JetBrains Gateway connection information"
  value = var.enable_jetbrains_gateway ? {
    host     = aws_spot_instance_request.dev.public_ip
    port     = 22
    username = "ubuntu"
    key_path = "~/.ssh/${var.ssh_key_name}.pem"
  } : null
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