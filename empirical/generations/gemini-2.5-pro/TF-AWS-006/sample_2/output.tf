terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1" # Replace with your desired region
}

variable "admin_ssh_cidr_blocks" {
  description = "A list of CIDR blocks for administrative SSH access."
  type        = list(string)
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance type for the web server."
  type        = string
  default     = "t3.micro"
}

variable "vpc_id" {
  description = "The VPC ID to launch the resources in. If not provided, the default VPC will be used."
  type        = string
  default     = null
}

data "aws_vpc" "selected" {
  default = var.vpc_id == null ? true : false
  id      = var.vpc_id
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

resource "aws_security_group" "web_server_sg" {
  name        = "web-server-sg"
  description = "Controls access to the web server"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description      = "Allow HTTPS from the internet"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "Allow SSH from admin IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_ssh_cidr_blocks
  }

  egress {
    description      = "Allow all outbound traffic"
    from