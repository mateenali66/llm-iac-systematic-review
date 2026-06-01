variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "admin_ssh_cidr" {
  description = "The CIDR block for administrative SSH access."
  type        = list(string)
  sensitive   = true
}

variable "instance_type" {
  description = "The EC2 instance type for the web server."
  type        = string
  default     = "t3.micro"
}

variable "project_name" {
  description = "The name of the project, used for tagging."
  type        = string
  default     = "webapp"
}

variable "environment" {
  description = "The deployment environment (e.g., prod, staging, dev)."
  type        = string
  default     = "production"
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
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
  name        = "${var.project_name}-sg-${var.environment}"
  description = "Controls access for the web server"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description      = "Allow HTTPS traffic from the internet"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "Allow SSH traffic from admin CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_ssh_cidr
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.web_server_sg.id]
  associate_public_ip_address = true

  tags = {
    Name        = "${var.project_name}-instance-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

output "instance_public_ip" {
  description = "The public IP address of the web server instance."
  value       = aws_instance.web_server.public_ip
}

output "instance_id" {
  description = "The ID of the web server instance."
  value       = aws_instance.web_server.id
}

output "security_group_id" {
  description = "The ID of the web server security group."
  value       = aws_security_group.web_server_sg.id
}