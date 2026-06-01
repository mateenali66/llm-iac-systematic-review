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
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
}

variable "project_name" {
  description = "Project name used for naming and tagging"
  type        = string

  validation {
    condition     = length(var.project_name) > 0
    error_message = "project_name must not be empty."
  }
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string

  validation {
    condition     = length(var.environment) > 0
    error_message = "environment must not be empty."
  }
}

variable "vpc_id" {
  description = "VPC ID where the ElastiCache cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the ElastiCache subnet group"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnets are required for high availability."
  }
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to access Redis (ingress on port 6379)"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access Redis (ingress on port 6379)"
  type        = list(string)
  default     = []
}

variable "node_type" {
  description = "ElastiCache node instance type"
  type        = string
  default     = "cache.t3.micro"
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "maintenance_window" {
  description = "Weekly maintenance window for ElastiCache"
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "snapshot_window" {
  description = "Daily snapshot window for ElastiCache"
  type        = string
  default     = "03:00-05:00"
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain automatic snapshots"
  type        = number
  default     = 7
}

variable "log_retention_in_days" {
  description = "CloudWatch Logs retention in days for Redis logs"
  type        = number
  default     = 30
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.additional_tags
  )

  name_prefix = "${var.project_name}-${var.environment}-redis"
}

# Ensure at least one ingress source is provided to avoid opening Redis to the world
locals {
  has_allowed_sgs   = length(var.allowed_security_group_ids) > 0
  has_allowed_cidrs = length(var.allowed_cidr_blocks) > 0
}

resource "aws_security_group" "redis" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for ${local.name_prefix} access on TCP/6379"
  vpc_id      = var.vpc_id

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description = "Allow all egress"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-sg" })
}

# Ingress from allowed security groups
resource "aws_security_group_rule" "redis_ingress_sg" {
  for_each                 = { for sg_id in var.allowed_security_group_ids : sg_id => sg_id }
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = each.value
  description              = "Allow Redis from SG ${each.value}"
}

# Ingress from allowed CIDR blocks
resource "aws_security_group_rule" "redis_ingress_cidr" {
  for_each          = { for cidr in var.allowed_cidr_blocks : cidr => cidr }
  type              = "ingress"
  from_port         = 6379
  to_port           = 6379
  protocol          = "tcp"
  security_group_id = aws_security_group.redis.id
  cidr_blocks       = [each.value]
  description       = "Allow Redis from CIDR ${each.value}"
}

# Fail the plan if no ingress sources are provided (security default)
resource "null_resource" "validate_ingress" {
  triggers = {
    has_sources = tostring(local.has_allowed_sgs || local.has_allowed_cidrs)
  }

  lifecycle {
    ignore_changes = [triggers]
  }

  provisioner "local-exec" {
    when    = destroy
    command = "true"
  }

  provisioner "local-exec" {
    when    = create
    command = "bash -c 'if [ \"${self.triggers.has_sources}\" != \"true\" ]; then echo \"ERROR: Provide at least one allowed_security_group_ids or allowed_cidr_blocks for Redis ingress.\" >&2; exit 1; fi'"
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = replace("${local.name_prefix}-subnets", "_", "-")
  subnet_ids = var.private_subnet_ids
  description = "Subnet group for ${local.name_prefix}"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-subnets" })
}

resource "random_password" "redis_auth" {
  length           = 32
  special          = false
  override_characters = ""
}

resource "random_id" "final_snapshot_suffix" {
  byte_length = 4
}

resource "aws_cloudwatch_log_group" "redis_slow_log" {
  name              = "/aws/elasticache/${local.name_prefix}/slow-log"
  retention_in_days = var.log_retention_in_days
  tags              = merge(local.common_tags, { Name = "/aws/elasticache/${local.name_prefix}/slow-log" })
}

resource "aws_cloudwatch_log_group" "redis_engine_log" {
  name              = "/aws/elasticache/${local.name_prefix}/engine-log"
  retention_in_days = var.log_retention_in_days
  tags              = merge(local.common_tags, { Name = "/aws/elasticache/${local.name_prefix}/engine-log" })
}

resource "aws_elasticache_parameter_group" "redis" {
  name   = replace("${local.name_prefix}-params", "_", "-")
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-params" })
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id          = replace("${var.project_name}-${var.environment}-rg-redis", "_", "-")
  description                   = "Redis replication group for ${local.name_prefix}"
  engine                        = "redis"
  engine_version                = var.engine_version
  node_type                     = var.node_type
  port                          = 6379
  parameter_group_name          = aws_elasticache_parameter_group.redis.name
  subnet_group_name             = aws_elasticache_subnet_group.redis.name
  security_group_ids            = [aws_security_group.redis.id]

  # High availability: 1 primary + 2 replicas = 3 nodes total
  num_node_groups               = 1
  replicas_per_node_group       = 2
  multi_az_enabled              = true
  automatic_failover_enabled    = true

  # Security
  at_rest_encryption_enabled    = true
  transit_encryption_enabled    = true
  auth_token                    = random_password.redis_auth.result

  # Ops
  maintenance_window            = var.maintenance_window
  snapshot_window               = var.snapshot_window
  snapshot_retention_limit      = var.snapshot_retention_limit
  apply_immediately             = false
  deletion_protection           = true
  final_snapshot_identifier     = replace("${local.name_prefix}-final-${random_id.final_snapshot_suffix.hex}", "_", "-")

  # Logging
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_engine_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}" })

  depends_on = [null_resource.validate_ingress]
}

output "redis_primary_endpoint" {
  description = "Primary endpoint address for the Redis replication group"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Reader endpoint address for the Redis replication group"
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "redis_port" {
  description = "Port number for Redis"
  value       = aws_elasticache_replication_group.redis.port
}

output "redis_auth_token" {
  description = "Auth token for Redis (handle securely)"
  value       = random_password.redis_auth.result
  sensitive   = true
}

output "redis_security_group_id" {
  description = "Security group ID attached to the Redis replication group"
  value       = aws_security_group.redis.id
}