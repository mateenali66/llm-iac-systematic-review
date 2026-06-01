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
  description = "Project / application name used for resource naming and tagging"
  type        = string
  default     = "saas-app"
}

variable "environment" {
  description = "Deployment environment (e.g., prod, staging)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where the RDS instance will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs (in different AZs) for the DB subnet group"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnets in different AZs are required for Multi-AZ RDS."
  }
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to connect to the database (e.g., application tier SGs)"
  type        = list(string)
  default     = []
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master database username"
  type        = string
  default     = "app_admin"
  sensitive   = true
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GiB"
  type        = number
  default     = 100
}

variable "max_allocated_storage" {
  description = "Upper bound for storage autoscaling in GiB"
  type        = number
  default     = 1000
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "Optional customer-managed KMS key ARN for storage and Performance Insights encryption. If null, a CMK is created."
  type        = string
  default     = null
}

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "rds-postgres"
    DataClass   = "customer-data"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

resource "aws_kms_key" "rds" {
  count = var.kms_key_arn == null ? 1 : 0

  description             = "CMK for ${local.name_prefix} RDS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "${local.name_prefix}-rds-kms"
  }
}

resource "aws_kms_alias" "rds" {
  count         = var.kms_key_arn == null ? 1 : 0
  name          = "alias/${local.name_prefix}-rds"
  target_key_id = aws_kms_key.rds[0].key_id
}

locals {
  effective_kms_key_arn = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.rds[0].arn
}

resource "random_password" "db_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "aws_secretsmanager_secret" "db_master" {
  name                    = "${local.name_prefix}/rds/master-credentials"
  description             = "Master credentials for ${local.name_prefix} PostgreSQL RDS"
  kms_key_id              = local.effective_kms_key_arn
  recovery_window_in_days = 30
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
  name        = "${local.name_prefix}-rds-subnets"
  description = "Subnet group for ${local.name_prefix} RDS"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name = "${local.name_prefix}-rds-subnets"
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for ${local.name_prefix} PostgreSQL RDS"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-rds-sg"
  }
}

resource "aws_security_group_rule" "rds_ingress_from_apps" {
  for_each = toset(var.allowed_security_group_ids)

  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = each.value
  description              = "Allow PostgreSQL from approved application security group"
}

resource "aws_security_group_rule" "rds_egress_none" {
  type              = "egress"
  from