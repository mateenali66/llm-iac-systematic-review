terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "allowed_cidr_blocks" {
  type    = list(string)
  default = []
}

variable "db_name" {
  type    = string
  default = "saas_primary"
}

variable "master_username" {
  type    = string
  default = "saasadmin"
}

variable "master_password" {
  type      = string
  sensitive = true
}

variable "tags" {
  type = map(string)
  default = {
    Environment = "production"
    Application = "saas"
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS PostgreSQL encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "rds" {
  name          = "alias/rds-postgres-saas"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_db_subnet_group" "primary" {
  name       = "saas-rds-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "rds" {
  name        = "saas-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_security_group_rule" "rds_ingress" {
  count             = length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.rds.id
}

resource "aws_db_parameter_group" "postgres15" {
  name   = "saas-postgres15-prod"
  family = "postgres15"

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = var.tags
}

resource "aws_db_instance" "primary" {
  identifier                          = "saas-primary-db"
  engine                              = "postgres"
  engine_version                      = "15.7"
  instance_class                      = "db.t3.medium"
  allocated_storage                   = 100
  max_allocated_storage               = 500
  storage_type                        = "gp3"
  storage_encrypted                   = true
  kms_key_id                          = aws_kms_key.rds.arn
  db_name                             = var.db_name
  username                            = var.master_username
  password                            = var.master_password
  multi_az                            = true
  db_subnet_group_name                = aws_db_subnet_group.primary.name
  vpc_security_group_ids              = [aws_security_group.rds.id]
  parameter_group_name                = aws_db_parameter_group.postgres15.name
  backup_retention_period             = 35
  backup_window                       = "03:00-04:00"
  maintenance_window                  = "sun:04:00-sun:05:00"
  auto_minor_version_upgrade          = true
  deletion_protection                 = true
  skip_final_snapshot                 = false
  final_snapshot_identifier           = "saas-primary-final-snapshot"
  copy_tags_to_snapshot               = true
  performance_insights_enabled        = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id     = aws_kms_key.rds.arn
  monitoring_interval                 = 60
  monitoring_role_arn                 = aws_iam_role.rds_enhanced_monitoring.arn
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]
  apply_immediately                   = false
  publicly_accessible                 = false

  tags = merge(var.tags, {
    Name = "saas-primary-db"
  })
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "saas-rds-monitoring-role"

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

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}