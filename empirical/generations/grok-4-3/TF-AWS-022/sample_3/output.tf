provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "allowed_cidr_blocks" {
  type    = list(string)
  default = ["10.0.0.0/8"]
}

resource "aws_security_group" "elasticache_redis" {
  name_prefix = "elasticache-redis-"
  vpc_id      = var.vpc_id
  description = "Security group for ElastiCache Redis"

  ingress {
    description = "Redis"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "elasticache-redis"
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "redis-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_parameter_group" "redis" {
  name   = "redis-app-params"
  family = "redis6.x"
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
  security_group_ids         = [aws_security_group.elasticache_redis.id]
  automatic_failover_enabled = true
  multi_az_enabled           = true
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  apply_immediately          = false
  auto_minor_version_upgrade = true

  tags = {
    Environment = "production"
    Purpose     = "application-caching"
  }
}