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

variable "name" {
  description = "Name prefix for ElastiCache resources"
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
  description = "List of private subnet IDs for the ElastiCache subnet group"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to connect to Redis"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to Redis"
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

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "parameter_group_family" {
  description = "Redis parameter group family"
  type        = string
  default     = "redis7"
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain automatic snapshots"
  type        = number
  default     = 7
}

variable "snapshot_window" {
  description = "Daily time range for snapshots (UTC)"
  type        = string
  default     = "03:00-05:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window (UTC)"
  type        = string
  default     = "sun:05:00-sun:07:00"
}

variable "kms_key_id" {
  description = "Optional KMS key ID for at-rest encryption. If null, AWS-managed key is used."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}

locals {
  common_tags = merge(
    {
      Name        = var.name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "random_password" "auth_token" {
  length           = 32
  special          = true
  override_special = "!&#$^<>-"
}

resource "aws_secretsmanager_secret" "redis_auth" {
  name                    = "${var.name}-redis-auth-token"
  description             = "Auth token for ${var.name} ElastiCache Redis cluster"
  recovery_window_in_days = 7
  kms_key_id              = var.kms_key_id
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id     = aws_secretsmanager_secret.redis_auth.id
  secret_string = random_password.auth_token.result
}

resource "aws_elasticache_subnet_group" "this" {
  name        = "${var.name}-subnet-group"
  description = "Subnet group for ${var.name} Redis cluster"
  subnet_ids  = var.subnet_ids
  tags        = local.common_tags
}

resource "aws_security_group" "this" {
  name        = "${var.name}-redis-sg"
  description = "Security group for ${var.name} ElastiCache Redis cluster"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ingress_sg" {
  for_each                 = toset(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.this.id
  source_security_group_id = each.value
  description              = "Allow Redis from security group ${each.value}"
}

resource "aws_security_group_rule" "ingress_cidr" {
  count             = length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 6379
  to_port           = 6379
  protocol          = "tcp"
  security_group_id = aws_security_group.this.id
  cidr_blocks       = var.allowed_cidr_blocks
  description       = "Allow Redis from approved CIDR blocks"
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.this.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound"
}

resource "aws_elasticache_parameter_group" "this" {
  name        = "${var.name}-params"
  family      = var.parameter_group_family
  description = "Custom parameter group for ${var.name} Redis cluster"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = "/aws/elasticache/${var.name}/slow-log"
  retention_in_days = 30
  kms_key_id        = var.kms_key_id
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "redis_engine" {
  name              = "/