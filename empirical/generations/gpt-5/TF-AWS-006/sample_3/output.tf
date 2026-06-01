terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where the security group and instance will be created"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the web server instance (typically a public subnet)"
  type        = string
}

variable "key_name" {
  description = "Name of the existing EC2 Key Pair to enable SSH access"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the web server"
  type        = string
  default     = "t3.micro"
}

variable "volume_size_gb" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "admin_ssh_ipv4_cidr_blocks" {
  description = "List of IPv4 CIDR blocks allowed to SSH into the instance"
  type        = list(string)

  validation {
    condition     = alltrue([for c in var.admin_ssh_ipv4_cidr_blocks : c != "0.0.0.0/0"])
    error_message = "Do not allow SSH from 0.0.0.0/0. Restrict to known admin IPv4 CIDR blocks."
  }
}

variable "admin_ssh_ipv6_cidr_blocks" {
  description = "List of IPv6 CIDR blocks allowed to SSH into the instance"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.admin_ssh_ipv6_cidr_blocks : c != "::/0"])
    error_message = "Do not allow SSH from ::/0. Restrict to known admin IPv6 CIDR blocks."
  }
}

variable "name" {
  description = "Name tag for resources"
  type        = string
  default     = "web-server"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

locals {
  common_tags = merge(
    {
      Application = "web"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
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
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_security_group" "web_sg" {
  name        = "${var.name}-sg"
  description = "Allow HTTPS from internet and SSH from admin CIDRs"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.name}-sg"
  })
}

# HTTPS from anywhere (IPv4)
resource "aws_security_group_rule" "https_ingress_ipv4" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web_sg.id
  description       = "Allow HTTPS from anywhere (IPv4)"
}

# HTTPS from anywhere (IPv6)
resource "aws_security_group_rule" "https_ingress_ipv6" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.web_sg.id
  description       = "Allow HTTPS from anywhere (IPv6)"
}

# SSH from admin IPv4 CIDRs
resource "aws_security_group_rule" "ssh_ingress_ipv4" {
  for_each          = toset(var.admin_ssh_ipv4_cidr_blocks)
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.web_sg.id
  description       = "Allow SSH from admin IPv4 CIDR"
}

# SSH from admin IPv6 CIDRs
resource "aws_security_group_rule" "ssh_ingress_ipv6" {
  for_each          = toset(var.admin_ssh_ipv6_cidr_blocks)
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  ipv6_cidr_blocks  = [each.value]
  security_group_id = aws_security_group.web_sg.id
  description       = "Allow SSH from admin IPv6 CIDR"
}

# Egress to anywhere (IPv4)
resource "aws_security_group_rule" "egress_all_ipv4" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web_sg.id
  description       = "Allow all outbound traffic (IPv4)"
}

# Egress to anywhere (IPv6)
resource "aws_security_group_rule" "egress_all_ipv6" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.web_sg.id
  description       = "Allow all outbound traffic (IPv6)"
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  monitoring                  = true
  disable_api_termination     = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = var.volume_size_gb
  }

  tags = merge(local.common_tags, {
    Name = var.name
    Role = "web-server"
  })
}