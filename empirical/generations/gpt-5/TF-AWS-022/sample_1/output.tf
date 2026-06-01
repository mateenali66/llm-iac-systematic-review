terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.1"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix used for naming ElastiCache resources."
  type        = string
  default     = "app-cache"
}

variable "environment" {
  description = "Deployment environment tag."
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "ID of the VPC where ElastiCache should be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs spanning multiple AZs for ElastiCache."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to access Redis."
  type        = list(string)
  default     = []
}

variable "allowed_ipv4_cidrs" {
  description = "List of IPv4 CIDR blocks allowed to access Redis."
  type        = list(string)
  default     = []
}

variable "engine_version" {
  description = "Redis engine version."
  type        = string
  default     = "7.0"
}

variable "node_type" {
  description = "Instance class for cache nodes."
  type        = string
  default     = "cache.t3.micro"
}

variable "replicas_per_node_group" {
  description = "Number of replicas per shard (node group). Set to 2 for a total of 3 nodes."
  type        = number
  default     = 2
}

variable "maintenance_window" {
  description = "Preferred maintenance window (UTC)."
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "snapshot_window" {
  description = "Daily time range (UTC) for taking snapshots."
  type        = string
  default     = "04:00-05:00"
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain automatic snapshots."
  type        = number
  default     = 7
}

variable "log_retention_days" {
  description = "Retention in days for CloudWatch Logs."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "terraform"
      Service     = "redis-cache"
    },
    var.tags
  )
}

resource "aws_security_group" "redis" {
  name        = "${var.name_prefix}-redis-sg"
  description = "Security group for Redis (TLS 6379)."
  vpc_id      = var.vpc_id
  tags        = local.common_tags
}

resource "aws_security_group_rule" "egress_vpc" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
  security_group_id = aws_security_group.redis.id
  description       = "Allow all outbound within VPC"
}

resource "aws_security_group_rule" "ingress_from_sgs" {
  for_each = toset(var.allowed_security_group_ids)

  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = each.value
  description              = "Allow TLS Redis from allowed SG"
}

resource "aws_security_group_rule" "ingress_from_cidrs" {
  for_each = toset(var.allowed_ipv4_cidrs)

  type              = "ingress"
  from_port         = 6379
  to_port           = 6379
  protocol          = "tcp"
  security_group_id = aws_security_group.redis.id
  cidr_blocks       = [each.value]
  description       = "Allow TLS Redis from allowed CIDR"
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.name_prefix}-redis-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = local.common_tags
}

resource "aws_kms_key" "elasticache" {
  description             = "KMS key for ElastiCache Redis at-rest encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.common_tags
}

resource "aws_kms_alias" "elasticache" {
  name          = "alias/${var.name_prefix}-elasticache"
  target_key_id = aws_kms_key.elasticache.key_id
}

resource "aws_cloudwatch_log_group" "engine" {
  name              = "/elasticache/${var.name_prefix}/engine"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "slow" {
  name              = "/elasticache/${var.name_prefix}/slowlog"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "random_password" "redis_auth_token" {
  length           = 32
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#$%^&*()-_=+[]{}<>:?.,|~`"
}

resource "aws_secretsmanager_secret" "redis_auth" {
  name = "${var.name_prefix}-redis-auth-token"
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id     = aws_secretsmanager_secret.redis_auth.id
  secret_string = random_password.redis_auth_token.result
}

resource "time_static" "created" {}

resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.name_prefix}-redis-params"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = local.common_tags
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id          = replace("${var.name_prefix}-redis", "/[^a-zA-Z0-9-]/", "-")
  description                   = "Highly available Redis replication group for application caching"
  engine                        = "redis"
  engine_version                = var.engine_version
  node_type                     = var.node_type
  parameter_group_name          = aws_elasticache_parameter_group.redis.name
  port                          = 6379

  subnet_group_name             = aws_elasticache_subnet_group.redis.name
  security_group_ids            = [aws_security_group.redis.id]

  automatic_failover_enabled    = true
  multi_az_enabled              = true

  num_node_groups               = 1
  replicas_per_node_group       = var.replicas_per_node_group

  at_rest_encryption_enabled    = true
  kms_key_id                    = aws_kms_key.elasticache.arn
  transit_encryption_enabled    = true
  auth_token                    = random_password.redis_auth_token.result

  maintenance_window            = var.maintenance_window
  snapshot_window               = var.snapshot_window
  snapshot_retention_limit      = var.snapshot_retention_limit
  final_snapshot_identifier     = "${replace(var.name_prefix, "/[^a-zA-Z0-9-]/", "-")}-final-${time_static.created.unix}"

  apply_immediately             = false

  log_delivery_configuration {
    destination_type = "cloudwatch-logs"
    destination      = aws_cloudwatch_log_group.engine.name
    log_format       = "json"
    log_type         = "engine-log"
  }

  log_delivery_configuration {
    destination_type = "cloudwatch-logs"
    destination      = aws_cloudwatch_log_group.slow.name
    log_format       = "json"
    log_type         = "slow-log"
  }

  tags = local.common_tags
}

output "redis_primary_endpoint" {
  description = "Primary endpoint address for Redis (TLS)."
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Reader endpoint address for Redis replicas (TLS)."
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "redis_port" {
  description = "Port for Redis."
  value       = aws_elasticache_replication_group.redis.port
}

output "redis_security_group_id" {
  description = "Security group ID attached to the Redis replication group."
  value       = aws_security_group.redis.id
}

output "redis_subnet_group_name" {
  description = "Name of the ElastiCache subnet group."
  value       = aws_elasticache_subnet_group.redis.name
}

output "redis_auth_token_secret_arn" {
  description = "Secrets Manager ARN containing the Redis AUTH token."
  value       = aws_secretsmanager_secret.redis_auth.arn
}