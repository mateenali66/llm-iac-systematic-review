provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "elasticache-vpc"
  }
}

resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "elasticache-subnet-${count.index}"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_security_group" "redis" {
  name        = "elasticache-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "elasticache-redis-sg"
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "elasticache-redis-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_elasticache_parameter_group" "redis" {
  name   = "elasticache-redis-params"
  family = "redis6.x"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "app-cache-redis"
  description                = "Production Redis cluster for application caching"
  node_type                  = "cache.t3.micro"
  num_cache_clusters         = 3
  engine                     = "redis"
  engine_version             = "6.2"
  port                       = 6379
  parameter_group_name       = aws_elasticache_parameter_group.redis.name
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis.id]
  automatic_failover_enabled = true
  multi_az_enabled           = true
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auto_minor_version_upgrade = true
  maintenance_window         = "sun:05:00-sun:06:00"
  snapshot_retention_limit   = 7
  snapshot_window            = "03:00-04:00"

  tags = {
    Environment = "production"
    Purpose     = "application-caching"
  }
}