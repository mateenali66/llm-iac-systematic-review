provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "jump_host" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t3.medium"
  vpc_security_group_ids = [aws_security_group.jump_host_sg.id]
  key_name               = "engineering_jump_host_key"
  tags = {
    Name        = "engineering_jump_host"
    Environment = "production"
    Purpose     = "internal_jump_host"
  }
}

resource "aws_security_group" "jump_host_sg" {
  name        = "engineering_jump_host_sg"
  description = "Security group for engineering jump host"
  vpc_id      = aws_vpc.jump_host_vpc.id

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

  tags = {
    Name        = "engineering_jump_host_sg"
    Environment = "production"
    Purpose     = "internal_jump_host_sg"
  }
}

resource "aws_vpc" "jump_host_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name        = "engineering_jump_host_vpc"
    Environment = "production"
    Purpose     = "internal_jump_host_vpc"
  }
}

resource "aws_subnet" "jump_host_subnet" {
  cidr_block = "10.0.1.0/24"
  vpc_id     = aws_vpc.jump_host_vpc.id
  availability_zone = "us-east-1a"
  tags = {
    Name        = "engineering_jump_host_subnet"
    Environment = "production"
    Purpose     = "internal_jump_host_subnet"
  }
}

resource "aws_internet_gateway" "jump_host_igw" {
  vpc_id = aws_vpc.jump_host_vpc.id
  tags = {
    Name        = "engineering_jump_host_igw"
    Environment = "production"
    Purpose     = "internal_jump_host_igw"
  }
}

resource "aws_route_table" "jump_host_rt" {
  vpc_id = aws_vpc.jump_host_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jump_host_igw.id
  }

  tags = {
    Name        = "engineering_jump_host_rt"
    Environment = "production"
    Purpose     = "internal_jump_host_rt"
  }
}

resource "aws_route_table_association" "jump_host_rta" {
  subnet_id      = aws_subnet.jump_host_subnet.id
  route_table_id = aws_route_table.jump_host_rt.id
}