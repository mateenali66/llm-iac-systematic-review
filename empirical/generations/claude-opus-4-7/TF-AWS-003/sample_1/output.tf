terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where the jump host will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID for the jump host (must have route to IGW)"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to the jump host (e.g., corporate VPN/office ranges). Avoid 0.0.0.0/0."
  type        = list(string)
}

variable "key_name" {
  description = "Name of the existing EC2 key pair for SSH access"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., prod, staging)"
  type        = string
  default     = "prod"
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "jump_host" {
  name        = "jump-host-sg"
  description = "Security group for the engineering jump host"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "jump-host-sg"
    Environment = var.environment
    Purpose     = "jump-host"
    ManagedBy   = "terraform"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_in" {
  for_each = toset(var.allowed_ssh_cidrs)

  security_group_id = aws_security_group.jump_host.id
  description       = "SSH access from approved CIDR"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.jump_host.id
  description       = "Allow outbound to private subnets and internet for patches"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_iam_role" "jump_host" {
  name = "jump-host-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "jump-host-role"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.jump_host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "jump_host" {
  name = "jump-host-profile"
  role = aws_iam_role.jump_host.name
}

resource "aws_instance" "jump_host" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.medium"
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.jump_host.id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.jump_host.name
  associate_public_ip_address = true
  ebs_optimized               = true
  monitoring                  = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name        = "jump-host-root"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }

  user_data_replace_on_change = true
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    dnf update -y
    dnf install -y amazon-ssm-agent
    systemctl enable --now amazon-ssm-agent
    # Harden SSH
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd
  EOF

  tags = {
    Name        = "jump-host"
    Environment = var.environment
    Purpose     = "engineering-jump-host"
    ManagedBy   = "terraform"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_eip" "jump_host" {
  instance = aws_instance.jump_host.id
  domain   = "vpc"

  tags = {
    Name        = "jump-host-eip"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

output "jump_host_instance_id" {
  description = "Instance ID of the jump host"
  value       = aws_instance.jump_host.id
}

output "jump_host_public_ip"