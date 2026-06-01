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
  description = "Public subnet ID for the jump host"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to the jump host (e.g., corporate VPN ranges)"
  type        = list(string)
}

variable "key_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks reachable from the jump host"
  type        = list(string)
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
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
    Name        = "jump-host-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
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

  tags = {
    Name = "jump-host-ssh-ingress"
  }
}

resource "aws_vpc_security_group_egress_rule" "ssh_to_private" {
  for_each = toset(var.private_subnet_cidrs)

  security_group_id = aws_security_group.jump_host.id
  description       = "SSH to private subnets"
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "https_out" {
  security_group_id = aws_security_group.jump_host.id
  description       = "HTTPS for package updates and SSM"
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

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
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
  iam_instance_profile        = aws_iam_instance_profile.jump_host.name
  key_name                    = var.key_name
  associate_public_ip_address = true
  ebs_optimized               = true
  monitoring                  = true
  disable_api_termination     = true

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
    }
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    dnf update -y
    dnf install -y amazon-ssm-agent
    systemctl enable --now amazon-ssm-agent
    # Harden SSH
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
    systemctl restart sshd
  EOF

  tags = {
    Name        = "jump-host"
    Role        = "bastion"
    Environment = var.environment
    ManagedBy   = "terraform"