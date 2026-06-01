provider "aws" {
  region = "us-east-1"
}

variable "ssh_key_name" {
  description = "The name of the EC2 Key Pair to allow SSH access to the instance."
  type        = string
  nullable    = false
}

variable "public_subnet_id" {
  description = "The ID of the public subnet in which to launch the EC2 instance."
  type        = string
  nullable    = false
}

variable "vpc_id" {
  description = "The ID of the VPC where the security group will be created."
  type        = string
  nullable    = false
}

variable "trusted_ssh_cidr_blocks" {
  description = "A list of trusted CIDR blocks for SSH access to the jump host."
  type        = list(string)
  default     = []
}

locals {
  instance_name = "internal-jump-host"
  tags = {
    Name        = local.instance_name
    Purpose     = "Jump Host"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "jump_host_sg" {
  name        = "${local.instance_name}-sg"
  description = "Controls access to the internal jump host"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow SSH from trusted IPs"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = var.trusted_ssh_cidr_blocks
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = local.tags
}

resource "aws_iam_role" "jump_host_role" {
  name               = "${local.instance_name}-role"
  description        = "IAM role for the jump host instance"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect