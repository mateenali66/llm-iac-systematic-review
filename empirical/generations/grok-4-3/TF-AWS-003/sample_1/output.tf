provider "aws" {
  region = "us-east-1"
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
  description = "CIDR blocks allowed to SSH to the jump host"
}

variable "key_name" {
  type        = string
  description = "Existing EC2 key pair name for SSH access"
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

resource "aws_security_group" "jump" {
  name        = "jump-host-sg"
  description = "Security group for internal jump host"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from allowed networks"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    description = "Allow all outbound"
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
    Name = "jump-host"
    Role = "bastion"
  }
}