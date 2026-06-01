resource "aws_security_group" "web_server_sg" {
  name        = "web-server-sg"
  description = "Security group for web server allowing HTTPS and SSH access"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from administrators"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-server-sg"
  }
}

resource "aws_instance" "web_server" {
  ami           = var.web_server_ami
  instance_type = var.web_server_instance_type
  key_name      = var.ssh_key_name
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [aws_security_group.web_server_sg.id]

  tags = {
    Name = "web-server"
  }
}