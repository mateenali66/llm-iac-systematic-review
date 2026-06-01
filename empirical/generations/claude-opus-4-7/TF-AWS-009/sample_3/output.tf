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

variable "project_name" {
  description = "Name of the project / application"
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
  description = "List of private subnet IDs for the DB subnet group (at least 2 AZs)"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnets in different AZs are required for production RDS."
  }
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to connect to the database (e.g. application tier)"
  type        = list(string)
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master DB username"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 100
}

variable "max_allocated_storage" {
  description = "Upper limit for storage autoscaling in GB"
  type        = number
  default     = 1000
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN for storage and Performance Insights encryption. If null, a new CMK is created."
  type        = string
  default     = null
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "rds-postgres"
  }
}

resource "aws_kms_key" "rds" {
  count = var.kms_key_arn == null ? 1 : 0

  description             = "KMS CMK for ${local.name_prefix} RDS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = local.tags
}

resource "aws_kms_alias" "rds" {
  count         = var.kms_key_arn == null ? 1 : 0
  name          = "alias/${local.name_prefix}-rds"
  target_key_id = aws_kms_key.rds[0].key_id
}

locals {
  kms_key_arn = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.rds[0].arn
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
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "db_master" {
  secret_id = aws_secretsmanager_secret.db_master.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_master.result
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = var.db_port
    dbname   = var.db_name
  })
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-db-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = local.tags
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for ${local.name_prefix} RDS PostgreSQL"
  vpc_id      = var.vpc_id

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "rds_ingress_from_apps" {
  for_each                 = toset(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = each.value
  description              = "PostgreSQL access from ${each.value}"
}

resource "aws_db_parameter_group" "this" {
  name        = "${local.name_prefix}-pg15-params"
  family      = "postgres15"
  description = "Custom parameter group for ${local.name_prefix} PostgreSQL 15"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_connections"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_disconnections"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_statement"
    value        = "ddl"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_min_du