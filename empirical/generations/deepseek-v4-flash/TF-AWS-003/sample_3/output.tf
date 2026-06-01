provider "aws" {
  region = "us-east-1"
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
    values = [false]
  }
}

resource "aws_security_group" "jump_host" {
  name        = "jump-host-sg"
  description = "Security group for jump host allowing SSH from internal network"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from internal network"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
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
  subnet_id              = data.aws_subnets.private.ids[0]
  vpc_security_group_ids = [aws_security_group.jump_host.id]
  associate_public_ip_address = false

  tags = {
    Name = "jump-host"
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}