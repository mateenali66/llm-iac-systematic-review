resource "aws_db_subnet_group" "primary" {
  name       = "saas-primary-db-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = {
    Name        = "saas-primary-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_security_group" "rds" {
  name        = "saas-primary-db-sg"
  description = "Security group for SaaS primary RDS instance"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL access from application servers"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.app_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "saas-primary-db-sg"
    Environment = var.environment
  }
}

resource "aws_db_parameter_group" "primary" {
  name   = "saas-primary-postgres15"
  family = "postgres15"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = {
    Name        = "saas-primary-postgres15"
    Environment = var.environment
  }
}

resource "aws_db_instance" "primary" {
  identifier              = "saas-primary-db"
  db_name                 = var.db_name
  engine                  = "postgres"
  engine_version          = "15.4"
  instance_class          = "db.t3.medium"
  allocated_storage       = 100
  storage_type            = "gp3"
  storage_encrypted       = true
  kms_key_id              = var.rds_kms_key_arn
  master_username         = var.db_username
  master_password         = var.db_password
  backup_retention_period = 30
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"
  multi_az                = true
  publicly_accessible     = false
  skip_final_snapshot     = false
  final_snapshot_identifier = "saas-primary-db-final-snapshot"
  copy_tags_to_snapshot   = true
  deletion_protection     = true
  db_subnet_group_name    = aws_db_subnet_group.primary.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  parameter_group_name    = aws_db_parameter_group.primary.name
  monitoring_interval     = 60
  monitoring_role_arn     = var.rds_monitoring_role_arn
  performance_insights_enabled = true
  performance_insights_retention_period = 731

  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade"
  ]

  lifecycle {
    ignore_changes = [
      master_password
    ]
  }

  tags = {
    Name        = "saas-primary-db"
    Environment = var.environment
  }
}