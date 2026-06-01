provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where the ElastiCache cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ElastiCache subnet group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to associate with the ElastiCache cluster"
  type        = list(string)
}

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "redis-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_elasticache_cluster" "redis_cluster" {
  cluster_id           = "app-cache-cluster"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 3
  parameter_group_name = "default.redis6.x"
  engine_version       = "6.2"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = var.security_group_ids

  apply_immediately = true

  maintenance_window = "sun:05:00-sun:06:00"

  snapshot_retention_limit = 7
  snapshot_window          = "03:00-05:00"

  tags = {
    Name        = "AppCacheCluster"
    Environment = "production"
    Purpose     = "Application Caching"
  }
}