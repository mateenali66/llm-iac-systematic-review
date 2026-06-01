provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_security_group" "jump_host_sg" {
  name        = "jump-host-sg"
  description = "Security group for internal jump host"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from internal network"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jump-host-sg"
  }
}

resource "aws_instance" "jump_host" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.medium"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.jump_host_sg.id]
  key_name               = var.key_name
  associate_public_ip_address = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "jump-host"
  }
}

variable "vpc_id" {
  description = "ID of the VPC where the jump host will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "ID of the private subnet for the jump host"
  type        = string
}

variable "key_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH into the jump host"
  type        = list(string)
}