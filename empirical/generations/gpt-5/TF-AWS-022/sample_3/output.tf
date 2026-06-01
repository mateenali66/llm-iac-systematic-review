terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Base name for the Redis resources"
  type        = string
  default     = "app-cache"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "VPC ID where ElastiCache will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ElastiCache subnet group"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to connect to Redis"
  type        = list(string)
  default     = []
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "num_cache_nodes" {
  description = "Number of cache nodes (1 primary + replicas) for replication group (cluster mode disabled)"
  type        = number
  default     = 3
}

variable "snapshot_retention_days" {
  description = "Number of days to retain automatic snapshots"
  type        = number
  default     = 7
}

variable "maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "sun:03:00-sun:05:00"
}

variable "snapshot_window" {
  description = "Preferred snapshot window"
  type        = string
  default     = "02:00-03:00"
}

variable "kms_key_id" {
  description = "KMS key ID for at-rest encryption (optional). If null, AWS managed key is used."
  type        = string
  default     = null
}

variable "secrets_kms_key_id" {
  description = "KMS key ID for encrypting the Redis credentials secret (optional)"
  type        = string
  default     = null
}

locals {
  rg_id             = regexreplace(lower(var.name), "[^a-z0-9-]", "-")
  tags = {
    Name        = var.name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_security_group" "redis" {
  name        = "${var.name}-redis-sg"
  description = "Security group for Redis allowing TLS connections from application SGs"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_security_group_ids
    content {
      description     = "Allow Redis TLS traffic from allowed SG"
      from_port       = 6379
      to_port         = 6379
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.name}-subnets"
  subnet_ids = var.private_subnet_ids
  description = "Subnet group for Redis"

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "redis_engine" {
  name              = "/aws/elasticache/redis/${local.rg_id}/engine"
  retention_in_days = 30
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = "/aws/elasticache/redis/${local.rg_id}/slow"
  retention_in_days = 30
  tags              = local.tags
}

resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.name}-paramgrp"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "tcp-keepalive"
    value = "300"
  }

  tags = local.tags
}

resource "random_password" "redis_default_user" {
  length  = 32
  special = false
}

resource "aws_elasticache_user" "default" {
  user_id            = "default"
  user_name          = "default"
  engine             = "REDIS"
  access_string      = "on ~* +@all"
  no_password_required = false
  passwords          = [random_password.redis_default_user.result]

  tags = local.tags
}

resource "aws_elasticache_user_group" "redis" {
  user_group_id = "${var.name}-usergrp"
  engine        = "REDIS"
  user_ids      = [aws_elasticache_user.default.id]

  tags = local.tags
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id          = local.rg_id
  description                   = "Redis replication group for application caching"
  engine                        = "redis"
  engine_version                = var.engine_version
  node_type                     = var.node_type
  number_cache_clusters         = var.num_cache_nodes
  parameter_group_name          = aws_elasticache_parameter_group.redis.name
  subnet_group_name             = aws_elasticache_subnet_group.redis.name
  security_group_ids            = [aws_security_group.redis.id]

  automatic_failover_enabled    = true
  multi_az_enabled              = true
  auto_minor_version_upgrade    = true

  at_rest_encryption_enabled    = true
  kms_key_id                    = var.kms_key_id
  transit_encryption_enabled    = true

  user_group_ids                = [aws_elasticache_user_group.redis.user_group_id]

  maintenance_window            = var.maintenance_window
  snapshot_window               = var.snapshot_window
  snapshot_retention_limit      = var.snapshot_retention_days
  port                          = 6379

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_engine.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  tags = local.tags

  depends_on = [
    aws_elasticache_user_group.redis
  ]
}

resource "aws_secretsmanager_secret" "redis_credentials" {
  name        = "/elasticache/redis/${local.rg_id}"
  description = "Credentials and endpoints for ${var.name} Redis"
  kms_key_id  = var.secrets_kms_key_id
  recovery_window_in_days = 7
  tags        = local.tags
}

resource "aws_secretsmanager_secret_version" "redis_credentials" {
  secret_id     = aws_secretsmanager_secret.redis_credentials.id
  secret_string = jsonencode({
    username             = aws_elasticache_user.default.user_name
    password             = random_password.redis_default_user.result
    engine               = "redis"
    port                 = 6379
    primary_endpoint     = aws_elasticache_replication_group.redis.primary_endpoint_address
    reader_endpoint      = aws_elasticache_replication_group.redis.reader_endpoint_address
    replication_group_id = aws_elasticache_replication_group.redis.id
    tls                  = true
  })
}

output "redis_primary_endpoint" {
  description = "Primary endpoint for Redis (writes)"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Reader endpoint for Redis (reads)"
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "redis_security_group_id" {
  description = "Security group ID attached to Redis"
  value       = aws_security_group.redis.id
}

output "redis_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Redis credentials and endpoints"
  value       = aws_secretsmanager_secret.redis_credentials.arn
}