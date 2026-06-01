terraform {
  required_version = ">= 1.5.0"

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
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "app-cache"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "vpc_id" {
  description = "VPC ID where the ElastiCache cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs for the ElastiCache subnet group (multi-AZ recommended)"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least two subnets in different AZs are required for high availability."
  }
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access Redis"
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to access Redis"
  type        = list(string)
  default     = []
}

variable "node_type" {
  description = "ElastiCache node instance type"
  type        = string
  default     = "cache.t3.micro"
}

variable "num_cache_clusters" {
  description = "Number of cache nodes (1 primary + replicas)"
  type        = number
  default     = 3
}

variable "redis_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain automatic snapshots"
  type        = number
  default     = 7
}

variable "snapshot_window" {
  description = "Daily window for snapshots (UTC)"
  type        = string
  default     = "03:00-05:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window (UTC)"
  type        = string
  default     = "sun:05:00-sun:07:00"
}

variable "kms_key_id" {
  description = "Optional KMS key ID for at-rest encryption. If null, AWS managed key is used."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags applied to all resources"
  type        = map(string)
  default     = {}
}

locals {
  name = "${var.project_name}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Component   = "elasticache-redis"
    },
    var.tags
  )
}

resource "random_password" "redis_auth_token" {
  length           = 32
  special          = true
  override_special = "!&#$^<>-"
}

resource "aws_secretsmanager_secret" "redis_auth_token" {
  name        = "${local.name}-redis-auth-token"
  description = "Auth token for ElastiCache Redis cluster ${local.name}"
  kms_key_id  = var.kms_key_id

  recovery_window_in_days = 7

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  secret_id     = aws_secretsmanager_secret.redis_auth_token.id
  secret_string = random_password.redis_auth_token.result
}

resource "aws_elasticache_subnet_group" "this" {
  name        = "${local.name}-subnet-group"
  description = "Subnet group for ${local.name} Redis cluster"
  subnet_ids  = var.subnet_ids

  tags = local.common_tags
}

resource "aws_security_group" "redis" {
  name        = "${local.name}-redis-sg"
  description = "Security group for ElastiCache Redis cluster ${local.name}"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name}-redis-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "redis_ingress_cidr" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = var.redis_port
  to_port           = var.redis_port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.redis.id
  description       = "Allow Redis access from approved CIDRs"
}

resource "aws_security_group_rule" "redis_ingress_sg" {
  for_each = toset(var.allowed_security_group_ids)

  type                     = "ingress"
  from_port                = var.redis_port
  to_port                  = var.redis_port
  protocol                 = "tcp"
  source_security_group_id = each.value
  security_group_id        = aws_security_group.redis.id
  description              = "Allow Redis access from SG ${each.value}"
}

resource "aws_elasticache_parameter_group" "this" {
  name        = "${local.name}-redis-params"
  family      = "redis7"
  description = "Custom parameter group for ${local.name}"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = "/aws/elasticache/${local.name}