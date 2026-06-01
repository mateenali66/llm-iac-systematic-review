terraform {
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
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "The ID of the VPC to deploy the resources into."
  type        = string
}

variable "admin_cidr_blocks" {
  description = "A list of CIDR blocks for administrators to allow SSH access."
  type        = list(string)
  default     = ["0.0.0.0/0"] # WARNING: This is insecure. Replace with your IP address.
}

variable "instance_type" {
  description = "The EC2 instance type for the web server."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "The name of the EC2 key pair to use for SSH access."
  type        = string
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  common_tags = {
    ManagedBy = "Terraform"
    Project   = "WebApp"
  }
}

resource "aws_security_group" "web_server_sg" {
  name        = "web-server-sg"
  description = "Controls inbound and outbound traffic for the web server."
  vpc_id      = var.vpc_id

  ingress {
    description      = "Allow HTTPS traffic from the internet"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "Allow SSH traffic from administrator IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "web-server-sg"
    }
  )
}

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_