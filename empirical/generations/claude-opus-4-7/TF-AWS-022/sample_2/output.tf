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
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for tagging and resource naming"
  type        = string
  default     = "app-cache"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "VPC ID where the ElastiCache cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs (in different AZs) for the ElastiCache subnet group"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs permitted to access Redis on port 6379"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks permitted to access Redis on port 6379"
  type        = list(string)
  default     = []
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_parameter_group_family" {
  description = "Redis parameter group family"
  type        = string
  default     = "redis7"
}

variable "node_type" {
  description = "Cache node instance type"
  type        = string
  default     = "cache.t3.micro"
}

variable "num_cache_clusters" {
  description = "Number of cache nodes in the replication group (1 primary + replicas)"
  type        = number
  default     = 3
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain automatic snapshots"
  type        = number
  default     = 7
}

variable "snapshot_window" {
  description = "Daily time range during which automated snapshots are created"
  type        = string
  default     = "03:00-05:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window"
  type        = string
  default     = "sun:05:00-sun:07:00"
}

locals {
  name = "${var.project_name}-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "random_password" "redis_auth_token" {
  length      = 64
  special     = false
  upper       = true
  lower       = true
  numeric     = true
  min_upper   = 4
  min_lower   = 4
  min_numeric = 4
}

resource "aws_secretsmanager_secret" "redis_auth_token" {
  name                    = "${local.name}-redis-auth-token"
  description             = "Auth token for ElastiCache Redis cluster ${local.name}"
  recovery_window_in_days = 7
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  secret_id     = aws_secretsmanager_secret.redis_auth_token.id
  secret_string = random_password.redis_auth_token.result
}

resource "aws_security_group" "redis" {
  name        = "${local.name}-redis-sg"
  description = "Security group for ElastiCache Redis ${local.name}"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${local.name}-redis-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "redis_ingress_sg" {
  for_each                 = toset(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = each.value
  security_group_id        = aws_security_group.redis.id
  description              = "Allow Redis access from security group ${each.value}"
}

resource "aws_security_group_rule" "redis_ingress_cidr" {
  count             = length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 6379
  to_port           = 6379
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.redis.id
  description       = "Allow Redis access from approved CIDR blocks"
}

resource "aws_security_group_rule" "redis_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.redis.id
  description       = "Allow all outbound traffic"
}

resource "aws_elasticache_subnet_group" "redis" {
  name        = "${local.name}-redis-subnets"
  description = "Subnet group for ElastiCache Redis ${local.name}"
  subnet_ids  = var.subnet_ids
  tags        = local.tags
}

resource "aws_elasticache_parameter_group" "redis" {
  name        = "${local.name}-redis-params"
  family      = var.redis_parameter_group_family
  description = "Parameter group for ElastiCache Redis ${local.name}"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = local.tags
}

resource "aws_kms_key" "redis" {
  description             = "KMS key for ElastiCache Redis ${local.name} encryption at rest"
  deletion_window