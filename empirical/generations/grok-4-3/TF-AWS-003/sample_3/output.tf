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
  type = string
}

variable "subnet_id" {
  type = string
}

variable "allowed_ssh_cidrs" {
  type    = list(string)
  default = []
}

variable "key_name" {
  type = string
}

resource "aws_security_group" "jump_host" {
  name_prefix = "jump-host-"
  vpc_id      = var.vpc_id
  description = "Security group for internal jump host"

  ingress {
    description = "SSH from allowed internal networks"
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

resource "aws_instance" "jump_host" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.medium"
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.jump_host.id]
  associate_public_ip_address = false
  monitoring                  = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "jump-host"
    Role = "bastion"
  }
}