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

variable "vpc_id" {
  description = "ID of the VPC where RDS will be provisioned."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group (across at least two AZs)."
  type        = list(string)
}

variable "db_identifier" {
  description = "Identifier for the RDS instance."
  type        = string
  default     = "prod-saas-postgres"
}

variable "db_name" {
  description = "Initial database name to create."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "app_user"
}

variable "rds_kms_key_arn" {
  description = "KMS Key ARN for RDS storage encryption."
  type        = string
}

variable "pi_kms_key_arn" {
  description = "KMS Key ARN for Performance Insights."
  type        = string
}

variable "secrets_manager_kms_key_arn" {
  description = "KMS Key ARN for storing the master user password in Secrets Manager (managed by RDS)."
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the database on port 5432."
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Security Group IDs allowed to access the database on port 5432."
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Deployment environment tag."
  type        = string
  default     = "prod"
}

variable "application" {
  description = "Application name tag."
  type        = string
  default     = "customer-saas"
}

variable "owner" {
  description = "Owner or team tag."
  type        = string
  default     = "platform-team"
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups."
  type        = number
  default     = 14
}

variable "backup_window" {
  description = "Preferred backup window in UTC (hh24:mi-hh24:mi)."
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window in UTC (ddd:hh24:mi-ddd:hh24:mi)."
  type        = string
  default     = "sun:06:00-sun:07:00"
}

variable "performance_insights_retention_period" {
  description = "Retention period (in days) for Performance Insights data. Valid: 7 or 731."
  type        = number
  default     = 7
}

variable "allocated_storage_gb" {
  description = "Initial allocated storage in GB."
  type        = number
  default     = 100
}

variable "max_allocated_storage_gb" {
  description = "Maximum storage (in GB) for autoscaling."
  type        = number
  default     = 1024
}

variable "storage_iops" {
  description = "IOPS for gp3 storage."
  type        = number
  default     = 3000
}

variable "storage_throughput" {
  description = "Storage throughput (MiB/s) for gp3 storage."
  type        = number
  default     = 125
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment."
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds."
  type        = number
  default     = 60
}

variable "publicly_accessible" {
  description = "Should the RDS instance be publicly accessible?"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection for the DB instance."
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "Retention period in days for RDS log groups."
  type        = number
  default     = 30
}

variable "ca_cert_identifier" {
  description = "CA certificate identifier to use for the DB instance."
  type        = string
  default     = "rds-ca-rsa2048-g1"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

resource "random_id" "final_snapshot" {
  byte_length = 4
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.db_identifier}-subnets"
  subnet_ids = var.private_subnet_ids
  description = "Private subnets for ${var.db_identifier}"

  tags = {
    Name        = "${var.db_identifier}-subnet-group"
    Environment = var.environment
    Application = var.application
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.db_identifier}-sg"
  description = "Security group for ${var.db_identifier} RDS PostgreSQL"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.db_identifier}-sg"
    Environment = var.environment
    Application = var.application
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

resource "aws_security_group_rule" "ingress_cidrs" {
  for_each = toset(var.allowed_cidr_blocks)

  type              = "Ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.rds.id
  description       = "Allow PostgreSQL from CIDR ${each.value}"
}

resource "aws_security_group_rule" "ingress_sgs" {
  for_each = toset(var.allowed_security_group_ids)

  type                     = "Ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = each.value
  security_group_id        = aws_security_group.rds.id
  description              = "Allow PostgreSQL from SG ${each.value}"
}

resource "aws_iam_role" "rds_monitoring" {
  name               = "${var.db_identifier}-monitoring-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.db_identifier}-monitoring-role"
    Environment = var.environment
    Application = var.application
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_parameter_group" "postgres15" {
  name        = "${var.db_identifier}-pg15"
  family      = "postgres15"
  description = "Parameter group for ${var.db_identifier} (PostgreSQL 15)"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "pg_stat_statements.track"
    value        = "all"
    apply_method = "immediate"
  }

  parameter {
    name         = "pg_stat_statements.max"
    value        = "10000"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "pg_stat_statements.save"
    value        = "on"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_min_duration_statement"
    value        = "2000"
    apply_method = "immediate"
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
    name         = "log_lock_waits"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "deadlock_timeout"
    value        = "1000"
    apply_method = "immediate"
  }

  parameter {
    name         = "password_encryption"
    value        = "scram-sha-256"
    apply_method = "immediate"
  }

  parameter {
    name         = "ssl_min_protocol_version"
    value        = "TLSv1.2"
    apply_method = "pending-reboot"
  }

  tags = {
    Name        = "${var.db_identifier}-pg15"
    Environment = var.environment
    Application = var.application
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "postgresql" {
  name              = "/aws/rds/instance/${var.db_identifier}/postgresql"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name        = "${var.db_identifier}-postgresql-logs"
    Environment = var.environment
    Application = var.application
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "upgrade" {
  name              = "/aws/rds/instance/${var.db_identifier}/upgrade"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name        = "${var.db_identifier}-upgrade-logs"
    Environment = var.environment
    Application = var.application
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

resource "aws_db_instance" "this" {
  identifier = var.db_identifier

  engine         = "postgres"
  engine_version = "15"

  instance_class = "db.t3.medium"

  db_name  = var.db_name
  username = var.db_username

  # Use AWS-managed Secrets Manager for master user password (kept out of Terraform state)
  manage_master_user_password    = true
  master_user_secret_kms_key_id  = var.secrets_manager_kms_key_arn

  storage_type          = "gp3"
  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.max_allocated_storage_gb
  iops                  = var.storage_iops
  storage_throughput    = var.storage_throughput

  multi_az               = var.multi_az
  publicly_accessible    = var.publicly_accessible
  port                   = 5432
  ca_cert_identifier     = var.ca_cert_identifier
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.this.name
  parameter_group_name   = aws_db_parameter_group.postgres15.name

  kms_key_id        = var.rds_kms_key_arn
  storage_encrypted = true

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.pi_kms_key_arn
  performance_insights_retention_period = var.performance_insights_retention_period

  auto_minor_version_upgrade = true
  apply_immediately          = false
  allow_major_version_upgrade = false

  deletion_protection  = var.deletion_protection
  copy_tags_to_snapshot = true

  iam_database_authentication_enabled = true

  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.db_identifier}-final-${random_id.final_snapshot.hex}"

  depends_on = [
    aws_cloudwatch_log_group.postgresql,
    aws_cloudwatch_log_group.upgrade
  ]

  tags = {
    Name        = var.db_identifier
    Environment = var.environment
    Application = var.application
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

output "rds_endpoint" {
  description = "Writer endpoint of the RDS instance."
  value       = aws_db_instance.this.address
}

output "rds_port" {
  description = "Port of the RDS instance."
  value       = aws_db_instance.this.port
}

output "rds_arn" {
  description = "ARN of the RDS instance."
  value       = aws_db_instance.this.arn
}

output "rds_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the master user password."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}