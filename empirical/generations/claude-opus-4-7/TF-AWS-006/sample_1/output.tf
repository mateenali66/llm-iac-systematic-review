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
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where the security group and EC2 instance will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the EC2 instance (should be a public subnet for web server)"
  type        = string
}

variable "admin_cidr_blocks" {
  description = "List of CIDR blocks allowed SSH access (restrict to corporate/VPN IPs)"
  type        = list(string)

  validation {
    condition     = !contains(var.admin_cidr_blocks, "0.0.0.0/0")
    error_message = "SSH access must not be open to the entire internet (0.0.0.0/0)."
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
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name used for resource tagging"
  type        = string
  default     = "web-server"
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
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "web_server" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "Security group for web server: HTTPS from internet, SSH from admins"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-sg"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "https_ipv4" {
  security_group_id = aws_security_group.web_server.id
  description       = "Allow HTTPS from internet (IPv4)"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = {
    Name = "${var.project_name}-${var.environment}-https-ipv4"
  }
}

resource "aws_vpc_security_group_ingress_rule" "https_ipv6" {
  security_group_id = aws_security_group.web_server.id
  description       = "Allow HTTPS from internet (IPv6)"
  cidr_ipv6         = "::/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = {
    Name = "${var.project_name}-${var.environment}-https-ipv6"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_admin" {
  for_each = toset(var.admin_cidr_blocks)

  security_group_id = aws_security_group.web_server.id
  description       = "Allow SSH from administrator network"
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"

  tags = {
    Name = "${var.project_name}-${var.environment}-ssh-admin"
  }
}

resource "aws_vpc_security_group_egress_rule" "all_ipv4" {
  security_group_id = aws_security_group.web_server.id
  description       = "Allow all outbound traffic (IPv4)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = {
    Name = "${var.project_name}-${var.environment}-egress-ipv4"
  }
}

resource "aws_vpc_security_group_egress_rule" "all_ipv6" {
  security_group_id = aws_security_group.web_server.id
  description       = "Allow all outbound traffic (IPv6)"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"

  tags = {
    Name = "${var.project_name}-${var.environment}-egress-ipv6"
  }
}

resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.web_server.id]
  key_name               = var.key_name

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
      Name        = "${var.project_name}-${var.environment}-root-volume"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}"