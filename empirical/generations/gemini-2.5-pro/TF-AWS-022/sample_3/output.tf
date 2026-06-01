terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  required_version = ">= 1.3"
}

data "aws_vpc" "selected" {
  default = true
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

resource "aws_security_group" "app_server_sg" {
  name        = "app-server-sg"
  description = "Security group for application servers"
  vpc_id      = data.aws_vpc.selected.id

  tags = {
    Name = "app-server-sg"
  }
}

resource "aws_security_group" "elasticache_sg" {
  name        = "elasticache-redis-sg"
  description = "Security group for ElastiCache Redis cluster"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description      = "Allow Redis traffic from application servers"
    from_port        = 6379
    to_port          = 6379
    protocol         = "tcp"
    security_groups  = [aws_security_group.app_server_sg.id]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    self             = false
  }

  tags = {
    Name = "elasticache-redis-sg"
  }
}

resource "aws_elasticache_subnet_group" "default" {