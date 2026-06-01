terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "ID of the VPC where the security group and instance will be created."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the web server EC2 instance."
  type        = string
}

variable "key_name" {
  description = "Name of an existing EC2 Key Pair to enable SSH access."
  type        = string
}

variable "admin_cidr_blocks" {
  description = "List of IPv4 CIDR blocks allowed SSH (22) access. Do not use 0.0.0.0/0."
  type        = list(string)

  validation {
    condition     = length(var.admin_cidr_blocks) > 0 && alltrue([for cidr in var.admin_cidr_blocks : cidr != "0.0.0.0/0"])
    error_message = "Provide at least one admin IPv4 CIDR block and do not include 0.0.0.0/0."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the web server."
  type        = string
  default     = "t3.micro"
}

variable "instance_name" {
  description = "Name tag for the web server EC2 instance."
  type        = string
  default     = "web-server"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

data "aws_ami" "al2023" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
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
  name        = "${var.instance_name}-sg"
  description = "Security group for web server allowing HTTPS from the internet and SSH from admin CIDRs"
  vpc_id      = var.vpc_id

  ingress {
    description      = "HTTPS from anywhere (IPv4 and IPv6)"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "SSH from admin CIDR ranges (IPv4)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    description      = "Allow all outbound traffic (IPv4 and IPv6)"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.instance_name}-sg"
  })
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  disable_api_termination     = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name = var.instance_name
  })
}

output "security_group_id" {
  description = "ID of the created security group."
  value       = aws_security_group.web_sg.id
}

output "instance_id" {
  description = "ID of the web server EC2 instance."
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Public IP address of the web server EC2 instance."
  value       = aws_instance.web.public_ip
}