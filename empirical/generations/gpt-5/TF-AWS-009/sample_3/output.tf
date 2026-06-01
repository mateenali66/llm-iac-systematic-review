terraform {
  required_version = ">= 1.5.0"

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

variable "vpc_id" {
  description = "VPC ID where the RDS instance will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group (across at least 2 AZs)"
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Security Group ID of the application that needs DB access (optional)"
  type        = string
  default     = null
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access PostgreSQL (use sparingly in production)"
  type        = list(string)
  default     = []
}

variable "db_identifier" {
  description = "RDS DB instance identifier"
  type        = string
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "dbadmin"
}

variable "allocated_storage" {
  description = "Initial allocated storage (GB)"
  type        = number
  default     = 100
}

variable "max_allocated_storage" {
  description = "Maximum storage (GB) for autoscaling"
  type        = number
  default     = 1000
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 14
}

variable "backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-05:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0 to disable)"
  type        = number
  default     = 60
}

variable "performance_insights_retention" {
  description = "Performance Insights retention period in days (7, month=731)"
  type        = number
  default     = 7
}

variable "kms_key_deletion_window_in_days" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 30
}

variable "enable_iam_auth" {
  description = "Enable IAM database authentication"
  type        = bool
  default     = true
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Whether to apply modifications immediately"
  type        = bool
  default     = false
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.5"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "iops" {
  description = "Provisioned IOPS (for gp3/gp2 if desired). Set null to use defaults"
  type        = number
  default     = null
}

variable "storage_throughput" {
  description = "Storage throughput in MB/s for gp3. Set null to use default"
  type        = number
  default     = null
}

locals {
  db_port = 5432
}

resource "aws_kms_key" "rds" {
  description             = "KMS CMK for encrypting RDS PostgreSQL storage and Performance Insights"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  tags                    = merge(var.tags, { Name = "${var.db_identifier}-rds-kms" })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.db_identifier}-rds-kms"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name               = "${var.db_identifier}-rds-enhanced-monitoring"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
  tags = merge(var.tags, { Name = "${var.db_identifier}-rds-enhanced-monitoring" })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_parameter_group" "pg15" {
  name        = "${var.db_identifier}-pg15-params"
  family      = "postgres15"
  description = "Parameter group for PostgreSQL 15 - ${var.db_identifier}"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "5000"
  }

  tags = merge(var.tags, { Name = "${var.db_identifier}-pg15-params" })
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.db_identifier}-db-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = merge(var.tags, { Name = "${var.db_identifier}-db-subnets" })
}

resource "aws_security_group" "rds" {
  name        = "${var.db_identifier}-rds-sg"
  description = "Security group for RDS PostgreSQL ${var.db_identifier}"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(var.tags, { Name = "${var.db_identifier}-rds-sg" })
}

resource "aws_security_group_rule" "from_app_sg" {
  count                    = var.app_security_group_id == null ? 0 : 1
  description              = "Allow PostgreSQL from application SG"
  type                     = "ingress"
  from_port                = local.db_port
  to_port                  = local.db_port
  protocol                 = "tcp"
  source_security_group_id = var.app_security_group_id
  security_group_id        = aws_security_group.rds.id
}

resource "aws_security_group_rule" "from_cidrs" {
  for_each          = toset(var.allowed_cidr_blocks)
  description       = "Allow PostgreSQL from approved CIDR"
  type              = "ingress"
  from_port         = local.db_port
  to_port           = local.db_port
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.rds.id
}

resource "random_password" "master" {
  length           = 32
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#$%&*()-_=+[]{}?:"
}

resource "aws_secretsmanager_secret" "db_master" {
  name                    = "rds/${var.db_identifier}/master"
  recovery_window_in_days = 30
  tags                    = merge(var.tags, { Name = "rds/${var.db_identifier}/master" })
}

resource "aws_secretsmanager_secret_version" "db_master" {
  secret_id     = aws_secretsmanager_secret.db_master.id
  secret_string = jsonencode({ username = var.master_username, password = random_password.master.result })
}

resource "aws_db_instance" "primary" {
  identifier                          = var.db_identifier
  engine                              = "postgres"
  engine_version                      = var.engine_version
  instance_class                      = "db.t3.medium"
  port                                = local.db_port

  db_name                             = var.db_name
  username                            = var.master_username
  password                            = random_password.master.result

  allocated_storage                   = var.allocated_storage
  max_allocated_storage               = var.max_allocated_storage
  storage_type                        = "gp3"
  iops                                = var.iops
  storage_throughput                  = var.storage_throughput

  multi_az                            = var.multi_az
  db_subnet_group_name                = aws_db_subnet_group.this.name
  vpc_security_group_ids              = [aws_security_group.rds.id]
  publicly_accessible                 = false

  parameter_group_name                = aws_db_parameter_group.pg15.name

  backup_retention_period             = var.backup_retention_period
  backup_window                       = var.backup_window
  maintenance_window                  = var.maintenance_window
  auto_minor_version_upgrade          = true
  allow_major_version_upgrade         = false

  deletion_protection                 = true
  skip_final_snapshot                 = false
  final_snapshot_identifier           = "${var.db_identifier}-final"

  storage_encrypted                   = true
  kms_key_id                          = aws_kms_key.rds.arn

  performance_insights_enabled        = true
  performance_insights_kms_key_id     = aws_kms_key.rds.arn
  performance_insights_retention_period = var.performance_insights_retention

  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]

  monitoring_interval                 = var.monitoring_interval
  monitoring_role_arn                 = aws_iam_role.rds_enhanced_monitoring.arn

  iam_database_authentication_enabled = var.enable_iam_auth

  apply_immediately                   = var.apply_immediately
  copy_tags_to_snapshot               = true

  tags = merge(var.tags, { Name = var.db_identifier })
}

output "rds_endpoint" {
  description = "Writer endpoint of the RDS instance"
  value       = aws_db_instance.primary.endpoint
}

output "rds_address" {
  description = "DNS address of the RDS instance"
  value       = aws_db_instance.primary.address
}

output "rds_port" {
  description = "Port the RDS instance listens on"
  value       = aws_db_instance.primary.port
}

output "rds_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.primary.id
}

output "rds_resource_id" {
  description = "RDS instance resource ID"
  value       = aws_db_instance.primary.resource_id
}

output "rds_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.primary.arn
}

output "rds_security_group_id" {
  description = "Security Group ID attached to RDS instance"
  value       = aws_security_group.rds.id
}

output "db_master_secret_arn" {
  description = "Secrets Manager ARN containing master credentials"
  value       = aws_secretsmanager_secret.db_master.arn
}

output "rds_kms_key_arn" {
  description = "KMS CMK ARN used for RDS encryption"
  value       = aws_kms_key.rds.arn
}