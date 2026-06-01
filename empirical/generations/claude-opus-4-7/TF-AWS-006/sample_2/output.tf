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
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where the security group and EC2 instance will be created"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the EC2 instance"
  type        = string
}

variable "admin_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH to the web server (restrict to corporate/admin IPs)"
  type        = list(string)
  validation {
    condition     = length(var.admin_ssh_cidrs) > 0 && !contains(var.admin_ssh_cidrs, "0.0.0.0/0")
    error_message = "admin_ssh_cidrs must be provided and must not include 0.0.0.0/0."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "project" {
  description = "Project name for tagging"
  type        = string
  default     = "web"
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_security_group" "web_server" {
  name        = "${var.project}-${var.environment}-web-sg"
  description = "Security group for web server - HTTPS from internet, SSH from admins"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-web-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "https_ipv4" {
  security_group_id = aws_security_group.web_server.id
  description       = "Allow HTTPS from the internet (IPv4)"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-https-ipv4"
  })
}

resource "aws_vpc_security_group_ingress_rule" "https_ipv6" {
  security_group_id = aws_security_group.web_server.id
  description       = "Allow HTTPS from the internet (IPv6)"
  cidr_ipv6         = "::/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-https-ipv6"
  })
}

resource "aws_vpc_security_group_ingress_rule" "ssh_admin" {
  for_each = toset(var.admin_ssh_cidrs)

  security_group_id = aws_security_group.web_server.id
  description       = "Allow SSH from administrator CIDR ${each.value}"
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-ssh-admin"
  })
}

resource "aws_vpc_security_group_egress_rule" "all_ipv4" {
  security_group_id = aws_security_group.web_server.id
  description       = "Allow all outbound traffic (IPv4)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-egress-ipv4"
  })
}

resource "aws_vpc_security_group_egress_rule" "all_ipv6" {
  security_group_id = aws_security_group.web_server.id
  description       = "Allow all outbound traffic (IPv6)"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-egress-ipv6"
  })
}

resource "aws_iam_role" "web_server" {
  name = "${var.project}-${var.environment}-web-role"

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

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.web_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web_server" {
  name = "${var.project}-${var.environment}-web-profile"
  role = aws_iam_role.web_server.name

  t