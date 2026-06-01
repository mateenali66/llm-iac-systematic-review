variable "name" {
  description = "Unique name for the RDS instance and related resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., prod, staging)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs across at least two AZs"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "Provide at least two private subnets across different AZs for Multi-AZ."
  }
}

variable "app_security_group_ids" {
  description = "List of application Security Group IDs allowed to connect to the DB (port 5432)"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to the DB (port 5432). Prefer SG-based rules."
  type        = list(string)
  default     = []
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "engine_version" {
  description = "PostgreSQL engine version (major.minor)"
  type        = string
  default     = "15.6"

  validation {
    condition     = can(regex("^15(\\.|$)", var.engine_version))
    error_message = "Engine version must be PostgreSQL 15.x."
  }
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "master_username" {
  description = "Master (admin) username"
  type        = string
  default     = "dbadmin"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 100
}

variable "max_allocated_storage" {
  description = "Maximum autoscaled storage in GB"
  type        = number
  default     = 1000
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 14
}

variable "backup_window" {
  description = "Preferred daily backup window in UTC, e.g., 03:00-04:00"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window in UTC, e.g., Sun:04:00-Sun:05:00"
  type        = string
  default     = "Sun:04:00-Sun:05:00"
}

variable "deletion_protection" {
  description = "Protect the DB from accidental deletion"
  type        = bool
  default     = true
}

variable "auto_minor_version_upgrade" {
  description = "Allow automatic minor version upgrades"
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0 to disable; 1,5,10,15,30,60)"
  type        = number
  default     = 60
}

variable "enable_iam_auth" {
  description = "Enable IAM database authentication"
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

locals {
  tags = merge(
    {
      Name        = var.name
      Environment = var.environment
      Terraform   = "true"
      Service     = "saas-db"
    },
    var.tags
  )
}

data "aws_partition" "current" {}

resource "aws_kms_key" "rds" {
  description             = "KMS CMK for RDS storage, Performance Insights, and Secrets Manager for ${var.name}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = local.tags
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_db_parameter_group" "this" {
  name        = "${var.name}-pg15"
  family      = "postgres15"
  description = "Parameter group for ${var.name} (PostgreSQL 15)"
  tags        = local.tags

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name  = "pg_stat_statements.max"
    value = "10000"
  }

  parameter {
    name  = "pg_stat_statements.track"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "2000"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_lock_waits"
    value = "1"
  }

  parameter {
    name  = "log_temp_files"
    value = "0"
  }

  parameter {
    name  = "track_io_timing"
    value = "1"
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = local.tags
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-rds"
  description = "Security group for ${var.name} RDS PostgreSQL"
  vpc_id      = var.vpc_id
  tags        = local.tags
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.rds.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all egress"
}

resource "aws_security_group_rule" "ingress_cidrs" {
  count             = length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  security_group_id = aws_security_group.rds.id
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  description       = "Allow PostgreSQL from approved CIDR ranges"
}

resource "aws_security_group_rule" "ingress_sgs" {
  for_each                 = toset(var.app_security_group_ids)
  type                     = "ingress"
  security_group_id        = aws_security_group.rds.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = each.value
  description              = "Allow PostgreSQL from application SG ${each.value}"
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name               = "${var.name}-rds-monitoring"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "this" {
  identifier = var.name

  engine         = "postgres"
  engine_version = var.engine_version

  instance_class          = var.instance_class
  multi_az                = true
  publicly_accessible     = false
  deletion_protection     = var.deletion_protection
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately       = false

  storage_type            = "gp3"
  allocated_storage       = var.allocated_storage
  max_allocated_storage   = var.max_allocated_storage
  storage_encrypted       = true
  kms_key_id              = aws_kms_key.rds.arn

  db_name                 = var.db_name
  username                = var.master_username
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.rds.arn

  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  parameter_group_name    = aws_db_parameter_group.this.name

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  performance_insights_enabled   = var.performance_insights_enabled
  performance_insights_kms_key_id = aws_kms_key.rds.arn

  iam_database_authentication_enabled = var.enable_iam_auth

  tags = local.tags

  depends_on = [
    aws_security_group_rule.egress_all,
    aws_iam_role_policy_attachment.rds_enhanced_monitoring
  ]
}

output "rds_endpoint" {
  description = "RDS endpoint address"
  value       = aws_db_instance.this.address
}

output "rds_port" {
  description = "RDS port"
  value       = aws_db_instance.this.port
}

output "rds_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.this.arn
}

output "rds_master_user_secret_arn" {
  description = "Secrets Manager ARN for the master user password"
  value       = try(aws_db_instance.this.master_user_secret[0].secret_arn, null)
}