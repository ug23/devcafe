variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "spot-dev"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "c7g.4xlarge"
}

variable "spot_max_price" {
  description = "Maximum price for spot instance (empty string for on-demand price)"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 100
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair in AWS (optional - not needed for SSM)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_pat" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_username" {
  description = "GitHub username"
  type        = string
  default     = ""
}

variable "github_email" {
  description = "GitHub email for git config"
  type        = string
  default     = ""
}

variable "github_repo_url" {
  description = "GitHub repository URL to clone"
  type        = string
  default     = ""
}

variable "auto_terminate_hours" {
  description = "Hours before auto-termination"
  type        = number
  default     = 2
  
  validation {
    condition     = var.auto_terminate_hours >= 1 && var.auto_terminate_hours <= 24
    error_message = "Auto-terminate hours must be between 1 and 24."
  }
}

variable "enable_jetbrains_gateway" {
  description = "Enable JetBrains Gateway ports"
  type        = bool
  default     = true
}