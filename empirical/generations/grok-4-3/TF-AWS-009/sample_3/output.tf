terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for the RDS instance"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the DB subnet group (minimum 2 AZs)"
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "Security group IDs allowed to connect to the database"
  default     = []
}

variable "db_name" {
  type        = string
  description = "Name of the initial database"
  default     = "saas_primary"
}

variable "db_username" {
  type        = string
  description = "Master username for the database"
  default     = "appadmin"
}

variable "allocated_storage" {
  type        = number
  description = "Initial allocated storage in GB"
  default     = 100
}

variable "max_allocated_storage" {
  type        = number
  description = "Maximum storage for autoscaling in GB"
  default     = 500
}

variable "backup_retention_period" {
  type        = number
  description = "Backup retention period in days"
  default     = 35
}

variable "tags" {
  type        = map(string)
  description = "Common tags for all resources"
  default     = {}
}

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "primary" {
  name       = "saas-primary-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "saas-primary-db-subnet-group"
  })
}

resource "aws_security_group" "rds" {
  name        = "saas-primary-rds-sg"
  description = "Security group for primary PostgreSQL RDS instance"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from allowed security groups"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "saas-primary-rds-sg"
  })
}

resource "aws_db_parameter_group" "postgres15" {
  name   = "saas-primary-postgres15"
  family = "postgres15"

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = merge(var.tags, {
    Name = "saas-primary-postgres15"
  })
}

resource "aws_db_instance" "primary" {
  identifier                          = "saas-primary-db"
  engine                              = "postgres"
  engine_version                      = "15.7"
  instance_class                      = "db.t3.medium"
  allocated_storage                   = var.allocated_storage
  max_allocated_storage               = var.max_allocated_storage
  storage_type                        = "gp3"
  storage_encrypted                   = true
  kms_key_id                          = null # Uses AWS managed key; replace with customer-managed KMS ARN for stricter control

  db_name                             = var.db_name
  username                            = var.db_username
  password                            = random_password.db_password.result
  db_subnet_group_name                = aws_db_subnet_group.primary.name
  vpc_security_group_ids              = [aws_security_group.rds.id]
  parameter_group_name                = aws_db_parameter_group.postgres15.name

  multi_az                            = true
  publicly_accessible                 = false
  deletion_protection                 = true
  skip_final_snapshot                 = false
  final_snapshot_identifier           = "saas-primary-db-final-snapshot"
  backup_retention_period             = var.backup_retention_period
  backup_window                       = "03:00-04:00"
  maintenance_window                  = "sun:04:00-sun:05:00"
  auto_minor_version_upgrade          = true
  copy_tags_to_snapshot               = true
  performance_insights_enabled        = true
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]

  tags = merge(var.tags, {
    Name        = "saas-primary-db"
    Environment = "production"
    Application = "saas-primary"
  })

  lifecycle {
    prevent_destroy = true
  }
}