provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "al2023" {
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
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for the jump host"
}

variable "subnet_id" {
  type        = string
  description = "Public subnet ID for the jump host"
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDR blocks permitted to SSH to the jump host"
  default     = []
}

variable "key_name" {
  type        = string
  description = "EC2 key pair name for SSH access"
}

resource "aws_security_group" "jump" {
  name        = "jump-host-sg"
  description = "Allow SSH to jump host only"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jump-host-sg"
  }
}

resource "aws_instance" "jump" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.medium"
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.jump.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  monitoring                  = true
  ebs_optimized               = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name        = "jump-host"
    Environment = "prod"
    Role        = "bastion"
  }
}