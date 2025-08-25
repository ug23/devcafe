terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Environment     = "development"
    ManagedBy      = "terraform"
    Project        = var.project_name
    AutoTerminate  = "true"
    TerminateTime  = timeadd(timestamp(), "${var.auto_terminate_hours}h")
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu_arm" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-subnet"
  })
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rt"
  })
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

resource "aws_security_group" "main" {
  name        = "${var.project_name}-sg"
  description = "Security group for development spot instance with SSM"
  vpc_id      = aws_vpc.main.id

  # SSM接続のためにはインバウンドルールは不要
  # すべてのアウトバウンド通信を許可（SSMエンドポイントへの接続用）
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sg"
  })
}

# EC2インスタンス用のIAMロール（SSM接続用）
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# SSM接続に必要なマネージドポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# インスタンスプロファイル
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = local.common_tags
}

data "template_file" "user_data" {
  template = file("${path.module}/setup.sh")
  
  vars = {
    github_pat         = var.github_pat
    github_username    = var.github_username
    github_email       = var.github_email
    github_repo_url    = var.github_repo_url
    auto_terminate_hours = var.auto_terminate_hours
    project_name       = var.project_name
  }
}

resource "aws_spot_instance_request" "dev" {
  ami                    = data.aws_ami.ubuntu_arm.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.main.id]
  subnet_id             = aws_subnet.main.id
  user_data             = data.template_file.user_data.rendered
  
  spot_price           = var.spot_max_price
  wait_for_fulfillment = true
  spot_type           = "one-time"
  
  instance_interruption_behavior = "terminate"

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-spot-instance"
  })
}

resource "aws_ec2_tag" "spot_instance_tags" {
  for_each    = local.common_tags
  resource_id = aws_spot_instance_request.dev.spot_instance_id
  key         = each.key
  value       = each.value
}

resource "aws_ec2_tag" "spot_instance_name" {
  resource_id = aws_spot_instance_request.dev.spot_instance_id
  key         = "Name"
  value       = "${var.project_name}-dev-instance"
}

# CloudWatch EventsとLambdaによる自動削除
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:TerminateInstances",
          "ec2:CancelSpotInstanceRequests",
          "ec2:DescribeSpotInstanceRequests",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "auto_terminate" {
  filename         = "lambda_terminate.zip"
  function_name    = "${var.project_name}-auto-terminate"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 60

  environment {
    variables = {
      PROJECT_NAME = var.project_name
    }
  }

  tags = local.common_tags
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "lambda_terminate.zip"
  
  source {
    content  = <<-EOT
import boto3
import os
from datetime import datetime, timezone

def handler(event, context):
    ec2 = boto3.client('ec2')
    project_name = os.environ['PROJECT_NAME']
    
    # インスタンスを検索
    response = ec2.describe_instances(
        Filters=[
            {'Name': 'tag:Project', 'Values': [project_name]},
            {'Name': 'tag:AutoTerminate', 'Values': ['true']},
            {'Name': 'instance-state-name', 'Values': ['running']}
        ]
    )
    
    current_time = datetime.now(timezone.utc)
    
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            
            # TerminateTimeタグを取得
            terminate_time_str = None
            for tag in instance.get('Tags', []):
                if tag['Key'] == 'TerminateTime':
                    terminate_time_str = tag['Value']
                    break
            
            if terminate_time_str:
                try:
                    terminate_time = datetime.fromisoformat(terminate_time_str.replace('Z', '+00:00'))
                    
                    if current_time >= terminate_time:
                        print(f"Terminating instance {instance_id}")
                        
                        # スポットリクエストをキャンセル
                        spot_requests = ec2.describe_spot_instance_requests(
                            Filters=[
                                {'Name': 'instance-id', 'Values': [instance_id]}
                            ]
                        )
                        
                        for request in spot_requests['SpotInstanceRequests']:
                            ec2.cancel_spot_instance_requests(
                                SpotInstanceRequestIds=[request['SpotInstanceRequestId']]
                            )
                        
                        # インスタンスを終了
                        ec2.terminate_instances(InstanceIds=[instance_id])
                        
                except Exception as e:
                    print(f"Error processing instance {instance_id}: {str(e)}")
    
    return {'statusCode': 200}
EOT
    filename = "index.py"
  }
}

resource "aws_cloudwatch_event_rule" "auto_terminate" {
  name                = "${var.project_name}-auto-terminate"
  description         = "Trigger auto-terminate check every 5 minutes"
  schedule_expression = "rate(5 minutes)"
  
  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.auto_terminate.name
  target_id = "lambda"
  arn       = aws_lambda_function.auto_terminate.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_terminate.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.auto_terminate.arn
}