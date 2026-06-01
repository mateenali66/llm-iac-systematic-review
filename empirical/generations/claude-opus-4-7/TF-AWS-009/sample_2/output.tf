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

variable "project" {
  description = "Project / application name"
  type        = string
  default     = "saas-app"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "vpc_id" {
  description = "VPC ID where the RDS instance will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs (minimum 2 in different AZs) for the DB subnet group"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnets in different AZs are required for Multi-AZ RDS."
  }
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to connect to the database (application tier)"
  type        = list(string)
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master database username"
  type        = string
  default     = "appadmin"
  sensitive   = true
}

variable "db_port" {
  description = "Database listening port"
  type        = number
  default     = 5432
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "allocated_storage" {
  description = "Initial allocated storage (GB)"
  type        = number
  default     = 100
}

variable "max_allocated_storage" {
  description = "Maximum storage for autoscaling (GB)"
  type        = number
  default     = 1000
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 30
}

variable "kms_key_id" {
  description = "Optional customer-managed KMS key ARN for storage encryption. If null, a new CMK is created."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge({
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "rds-postgres"
  }, var.tags)
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "rds" {
  count                   = var.kms_key_id == null ? 1 : 0
  description             = "KMS key for ${local.name_prefix} RDS encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-kms"
  })
}

resource "aws_kms_alias" "rds" {
  count         = var.kms_key_id == null ? 1 : 0
  name          = "alias/${local.name_prefix}-rds"
  target_key_id = aws_kms_key.rds[0].key_id
}

locals {
  kms_key_arn = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.rds[0].arn
}

resource "random_password" "db_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "aws_secretsmanager_secret" "db_master" {
  name                    = "${local.name_prefix}/rds/master-credentials"
  description             = "Master credentials for ${local.name_prefix} RDS PostgreSQL"
  kms_key_id              = local.kms_key_arn
  recovery_window_in_days = 30

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_master" {
  secret_id = aws_secretsmanager_secret.db_master.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_master.result
    engine   = "postgres"
    port     = var.db_port
    dbname   = var.db_name
  })
}

resource "aws_db_subnet_group" "this" {
  name        = "${local.name_prefix}-rds-subnets"
  description = "Subnet group for ${local.name_prefix} RDS PostgreSQL"
  subnet_ids  = var.private_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-subnets"
  })
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for ${local.name_prefix} RDS PostgreSQL"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "rds_ingress_app" {
  for_each                 = toset(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = each.value
  description              = "PostgreSQL access from application security group ${each.value}"
}

resource "aws_db_parameter_group" "this" {
  name        = "${local.name_prefix}-pg15-params"
  family      =