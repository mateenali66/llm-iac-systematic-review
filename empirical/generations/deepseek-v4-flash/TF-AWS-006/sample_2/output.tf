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
  description = "List of CIDR blocks for administrative SSH access"
  type        = list(string)
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "production"
}

variable "ami_id" {
  description = "AMI ID for the web server EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet ID where the EC2 instance will be launched"
  type        = string
}