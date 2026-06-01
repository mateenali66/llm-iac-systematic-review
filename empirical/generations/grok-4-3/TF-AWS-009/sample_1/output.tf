variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "allowed_cidrs" { type = list(string) default = ["10.0.0.0/8"] }
variable "db_password" { type = string sensitive = true }

resource "aws_db_subnet_group" "this" {
  name       = "saas-primary-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags = { Name = "saas-primary-db-subnet-group" }
}

resource "aws_security_group" "rds" {
  name        = "saas-primary-rds-sg"
  vpc_id      = var.vpc_id
  description = "RDS PostgreSQL access"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "saas-primary-rds-sg" }
}

resource "aws_db_parameter_group" "this" {
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
}

resource "aws_iam_role" "rds_monitoring" {
  name = "saas-rds-enhanced-monitoring"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "this" {
  identifier              = "saas-primary-db"
  engine                  = "postgres"
  engine_version          = "15.4"
  instance_class          = "db.t3.medium"
  allocated_storage       = 100
  storage_type            = "gp3"
  storage_encrypted       = true
  db_name                 = "saas"
  username                = "saasadmin"
  password                = var.db_password

  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  parameter_group_name    = aws_db_parameter_group.this.name

  multi_az                = true
  publicly_accessible     = false
  backup_retention_period = 14
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"
  deletion_protection     = true
  skip_final_snapshot     = false
  final_snapshot_identifier = "saas-primary-db-final-snapshot"
  copy_tags_to_snapshot   = true

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn

  apply_immediately = false

  tags = { Name = "saas-primary-db" }
}