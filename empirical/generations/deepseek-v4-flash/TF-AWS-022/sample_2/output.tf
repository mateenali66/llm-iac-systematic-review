provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "redis" {
  name        = "redis-cache-sg"
  description = "Security group for ElastiCache Redis cluster"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [] # Replace with application security group IDs
    cidr_blocks     = [] # Replace with allowed CIDR blocks if needed
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "redis-cache-sg"
    Environment = "production"
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "redis-cache-subnet-group"
  subnet_ids = data.aws_subnets.private.ids
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "redis-cache-cluster"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 3
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]

  maintenance_window = "sun:05:00-sun:06:00"
  snapshot_window    = "03:00-04:00"
  snapshot_retention_limit = 7

  tags = {
    Name        = "redis-cache-cluster"
    Environment = "production"
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

  tags = {
    Tier = "private"
  }
}