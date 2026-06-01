terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for DB subnet group"
  type        = list(string)
}

variable "database_name" {
  description = "Database name"
  type        = string
  default     = "saasapp"
}

variable "master_username" {
  description = "Master username"
  type        = string
  default     = "saasadmin"
}

variable "master_password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "allowed_security_groups" {
  description = "Security groups allowed to access the database"
  type        = list(string)
}

locals {
  name_prefix = "saas-app-${var.environment}"
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "${local.name_prefix}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for RDS PostgreSQL instance"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL access from allowed security groups"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-rds-sg"
    Environment = var.environment
  }
}

resource "aws_rds_cluster_parameter_group" "main" {
  family = "aurora-postgresql15"
  name   = "${local.name_prefix}-cluster-param-group"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "5000"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,auto_explain"
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_rds_cluster" "main" {
  cluster_identifier              = "${local.name_prefix}-postgres-cluster"
  engine                          = "aurora-postgresql"
  engine_version                  = "15.4"
  database_name                   = var.database_name
  master_username                 = var.master_username
  master_password                 = var.master_password
  db_subnet_group_name            = aws_db_subnet_group.main.name
  vpc_security_group_ids          = [aws_security_group.rds.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name
  backup_retention_period         = 7
  preferred_backup_window         = "03:00-04:00"
  preferred_maintenance_window    = "sun:04:00-sun:05:00"
  skip_final_snapshot             = false
  final_snapshot_identifier       = "${local.name_prefix}-final-snapshot"
  storage_encrypted               = true
  deletion_protection             = true
  apply_immediately               = false

  serverlessv2_scaling_configuration {
    max_capacity = 2.0
    min_capacity = 0.5
  }

  tags = {
    Name        = "${local.name_prefix}-postgres-cluster"
    Environment = var.environment
  }
}

resource "aws_rds_cluster_instance" "main" {
  count              = 2
  identifier         = "${local.name_prefix}-postgres-instance-${count.index}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  publicly_accessible          = false
  auto_minor_version_upgrade   = true
  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_enhanced_monitoring.arn

  tags = {
    Name        = "${local.name_prefix}-postgres-instance-${count.index}"
    Environment = var.environment
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${local.name_prefix}-rds-enhanced-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

output "rds_cluster_endpoint" {
  description = "RDS cluster endpoint"
  value       = aws_rds_cluster.main.endpoint
}

output "rds_cluster_reader_endpoint" {
  description = "RDS cluster reader endpoint"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "rds_cluster_id" {
  description = "RDS cluster ID"
  value       = aws_rds_cluster.main.id
}