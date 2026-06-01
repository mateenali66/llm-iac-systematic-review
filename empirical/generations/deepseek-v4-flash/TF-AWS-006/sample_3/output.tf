resource "aws_security_group" "web_server_sg" {
  name        = "web-server-sg"
  description = "Security group for web server allowing HTTPS and SSH"
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
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "web-server-sg"
    Environment = var.environment
  }
}

resource "aws_instance" "web_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.web_server_sg.id]

  associate_public_ip_address = true

  tags = {
    Name        = "web-server"
    Environment = var.environment
  }
}

variable "vpc_id" {
  description = "The VPC ID where the security group will be created"
  type        = string
}

variable "admin_cidr_blocks" {
  description = "List of CIDR blocks allowed for SSH access"
  type        = list(string)
}

variable "ami_id" {
  description = "AMI ID for the web server EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type for the web server"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet ID where the web server will be launched"
  type        = string
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "production"
}