provider "aws" {
  region = "us-west-2"
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "app-cache"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 3
  parameter_group_name = "default.redis6.x"
  port                = 6379
  security_group_ids = [aws_security_group.redis.id]
  subnet_group_name   = aws_elasticache_subnet_group.redis.name
}

resource "aws_security_group" "redis" {
  name        = "redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = aws_vpc.redis.id

  ingress {
    from_port = 6379
    to_port   = 6379
    protocol  = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc" "redis" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "redis-subnet"
  subnet_ids = [aws_subnet.redis.id]
}

resource "aws_subnet" "redis" {
  cidr_block = "10.0.1.0/24"
  vpc_id     = aws_vpc.redis.id
  availability_zone = "us-west-2a"
}