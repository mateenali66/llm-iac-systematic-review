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

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "saas_primary"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "saas_admin"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for DB subnet group"
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "Security groups allowed to access the database"
  type        = list(string)
}

locals {
  name_prefix = "saas-primary-db"
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "${local.name_prefix}-subnet-group"
    Environment = var.environment
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for RDS PostgreSQL instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
    description     = "PostgreSQL access from application servers"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${local.name_prefix}-sg"
    Environment = var.environment
  }
}

resource "random_password" "db_password" {
  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${local.name_prefix}-credentials"
  description = "RDS PostgreSQL database credentials"

  tags = {
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
  })
}

resource "aws_db_parameter_group" "main" {
  name   = "${local.name_prefix}-param-group"
  family = "postgres15"

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_db_instance" "main" {
  identifier              = local.name_prefix
  db_name                 = var.db_name
  username                = var.db_username
  password                = random_password.db_password.result
  engine                  = "postgres"
  engine_version          = "15.4"
  instance_class          = "db.t3.medium"
  allocated_storage       = 100
  storage_type            = "gp3"
  storage_encrypted       = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"
  multi_az                = true
  publicly_accessible     = false
  skip_final_snapshot     = false
  final_snapshot_identifier = "${local.name_prefix}-final-snapshot"
  copy_tags_to_snapshot   = true
  deletion_protection     = true
  performance_insights_enabled = true
  performance_insights_retention_period = 7
  monitoring_interval     = 60
  monitoring_role_arn     = aws_iam_role.rds_enhanced_monitoring.arn
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  parameter_group_name    = aws_db_parameter_group.main.name
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  timeouts {
    create = "60m"
    update = "80m"
    delete = "60m"
  }

  tags = {
    Name        = local.name_prefix
    Environment = var.environment
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${local.name_prefix}-enhanced-monitoring-role"

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