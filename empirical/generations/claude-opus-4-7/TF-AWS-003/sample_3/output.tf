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

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = var.environment
      Purpose     = "JumpHost"
    }
  }
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "production"
}

variable "vpc_id" {
  description = "VPC ID where the jump host will be deployed"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for the jump host"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH to the jump host (e.g., corporate VPN/office IPs)"
  type        = list(string)
  validation {
    condition     = length(var.allowed_ssh_cidrs) > 0 && !contains(var.allowed_ssh_cidrs, "0.0.0.0/0")
    error_message = "allowed_ssh_cidrs must be set to specific CIDRs and must not contain 0.0.0.0/0."
  }
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair for SSH access"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets the jump host needs to reach via SSH"
  type        = list(string)
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
  description = "Security group for engineering jump host"
  vpc_id      = var.vpc_id

  tags = {
    Name = "jump-host-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_in" {
  for_each = toset(var.allowed_ssh_cidrs)

  security_group_id = aws_security_group.jump_host.id
  description       = "SSH from approved CIDR"
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ssh_to_private" {
  for_each = toset(var.private_subnet_cidrs)

  security_group_id = aws_security_group.jump_host.id
  description       = "SSH egress to private subnets"
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "https_out" {
  security_group_id = aws_security_group.jump_host.id
  description       = "HTTPS egress for package updates and SSM"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
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
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.jump_host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "jump_host" {
  name = "jump-host-instance-profile"
  role = aws_iam_role.jump_host.name
}

resource "aws_eip" "jump_host" {
  domain = "vpc"

  tags = {
    Name = "jump-host-eip"
  }
}

resource "aws_instance" "jump_host" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.medium"
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.jump_host.id]
  key_name                    = var.ssh_key_name
  iam_instance_profile        = aws_iam_instance_profile.jump_host.name
  associate_public_ip_address = false
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
      Name = "jump-host-root"
    }
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    dnf update -y
    dnf install -y amazon-ssm-agent
    systemctl enable --now amazon-ssm-agent
    # Harden SSH
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_