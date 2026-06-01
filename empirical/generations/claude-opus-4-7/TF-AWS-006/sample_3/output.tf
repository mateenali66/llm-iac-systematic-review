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
  description = "Subnet ID for the EC2 instance"
  type        = string
}

variable "admin_cidr_blocks" {
  description = "List of CIDR blocks allowed to SSH into the web server (restrict to admin IPs)"
  type        = list(string)
  validation {
    condition     = !contains(var.admin_cidr_blocks, "0.0.0.0/0")
    error_message = "SSH access must not be open to the world (0.0.0.0/0)."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the existing EC2 key pair for SSH access"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
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
  name        = "web-server-sg-${var.environment}"
  description = "Security group for web server allowing HTTPS from internet and SSH from administrators"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "web-server-sg-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "https_inbound" {
  security_group_id = aws_security_group.web_server.id
  description       = "Allow HTTPS inbound from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = {
    Name        = "https-inbound"
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_admin_inbound" {
  for_each = toset(var.admin_cidr_blocks)

  security_group_id = aws_security_group.web_server.id
  description       = "Allow SSH inbound from administrator CIDR ${each.value}"
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"

  tags = {
    Name        = "ssh-admin-inbound"
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.web_server.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = {
    Name        = "all-outbound"
    Environment = var.environment
  }
}

resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.web_server.id]
  key_name               = var.key_name

  associate_public_ip_address = true
  monitoring                  = true
  ebs_optimized               = true

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
      Name        = "web-server-root-${var.environment}"
      Environment = var.environment
    }
  }

  tags = {
    Name        = "web-server-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Role        = "web"
  }

  lifecycle {
    create_before_destroy = true
  }
}

output "security_group_id" {
  description = "ID of the web server security group"
  value       = aws_security_group.web_server.id
}

output "instance_id" {
  description = "ID of the web server EC2 instance"
  value       = aws_instance.web_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the web server"
  value       = aws_instance.web_server.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the web server"
  value       = aws_instance.web_server.private_ip
}