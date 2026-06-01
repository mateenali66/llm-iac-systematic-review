provider "aws" {
  region = "us-west-2"
}

resource "aws_security_group" "web_server_sg" {
  name        = "web_server_sg"
  description = "Security group for web server EC2 instance"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # restrict SSH access to a specific IP range for administrators
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web_server_sg"
  }
}

resource "aws_instance" "web_server" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_server_sg.id]
  key_name               = "admin_key"

  tags = {
    Name = "web_server"
  }
}