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
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["false"]
  }
}

resource "aws_security_group" "jump_host_sg" {
  name_prefix = "jump-host-sg"
  description = "Security group for jump host"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "SSH access from internal network"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "jump-host-sg"
  }
}

resource "aws_instance" "jump_host" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.medium"
  subnet_id                   = data.aws_subnets.private.ids[0]
  vpc_security_group_ids      = [aws_security_group.jump_host_sg.id]
  associate_public_ip_address = false

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  disable_api_termination = false
  instance_initiated_shutdown_behavior = "stop"

  tags = {
    Name = "internal-jump-host"
    Role = "jump-host"
  }
}