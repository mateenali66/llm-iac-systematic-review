provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "jump_host" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t3.medium"
  vpc_security_group_ids = [aws_security_group.jump_host_sg.id]
  key_name               = "jump_host_key"
  tags = {
    Name = "Internal Jump Host"
  }
}

resource "aws_security_group" "jump_host_sg" {
  name        = "jump_host_sg"
  description = "Security group for internal jump host"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "jump_host_key" {
  key_name   = "jump_host_key"
  public_key = file("~/.ssh/jump_host_key.pub")
}