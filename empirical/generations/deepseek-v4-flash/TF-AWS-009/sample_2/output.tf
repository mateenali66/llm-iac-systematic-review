provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for RDS deployment"
  type        = string
  default     = "us-east-1"
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
  default     = "saasdb"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to connect to RDS"
  type        = list(string)
  default     = []
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

resource "aws_db_subnet_group" "main" {
  name       = "saas-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "saas-db-subnet-group"
    Environment = "production"
    Application = "saas-application"
  }
}

resource "aws_security_group" "rds" {
  name        = "saas-rds-sg"
  description = "Security group for SaaS RDS PostgreSQL instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "PostgreSQL access from allowed security groups"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "saas-rds-sg"
    Environment = "production"
    Application = "saas-application"
  }
}

resource "aws_db_parameter_group" "postgres15" {
  name        = "saas-postgres15-params"
  family      = "postgres15"
  description = "Custom parameter group for PostgreSQL 15 SaaS database"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = {
    Name        = "saas-postgres15-params"
    Environment = "production"
    Application = "saas-application"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "saas-postgresql-15"

  engine                      = "postgres"
  engine_version              = "15.7"
  instance_class              = "db.t3.medium"
  allocated_storage           = 100
  max_allocated_storage       = 500
  storage_type                = "gp3"
  storage_encrypted           = true
  kms_key_id                  = null

  db_name                     = var.db_name
  username                    = var.db_username
  password                    = var.db_password
  port                        = 5432

  db_subnet_group_name        = aws_db_subnet_group.main.name
  vpc_security_group_ids      = [aws_security_group.rds.id]
  parameter_group_name        = aws_db_parameter_group.postgres15.name

  backup_retention_period     = 30
  backup_window               = "03:00-04:00"
  maintenance_window          = "sun:05:00-sun:06:00"
  copy_tags_to_snapshot       = true
  delete_automated_backups    = false
  skip_final_snapshot         = false
  final_snapshot_identifier   = "saas-postgresql-15-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  apply_immediately           = false

  multi_az                    = true
  publicly_accessible         = false
  monitoring_interval         = 60
  monitoring_role_arn         = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  deletion_protection = true

  tags = {
    Name        = "saas-postgresql-15"
    Environment = "production"
    Application = "saas-application"
    ManagedBy   = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role" "rds_monitoring" {
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

  tags = {
    Name        = "saas-rds-monitoring-role"
    Environment = "production"
    Application = "saas-application"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.postgres.port
}

output "rds_db_name" {
  description = "Initial database name"
  value       = aws_db_instance.postgres.db_name
}