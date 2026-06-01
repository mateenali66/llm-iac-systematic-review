variable "vpc_id" {
  description = "The ID of the VPC where the RDS instance will be deployed."
  type        = string
}

variable "database_subnets" {
  description = "A list of private subnet IDs for the RDS DB subnet group."
  type        = list(string)
}

variable "application_security_group_id" {
  description = "The ID of the security group for the application that needs to connect to the database."
  type        = string
}

variable "db_name" {
  description = "The name of the database to create."
  type        = string
  default     = "saas_primary_db"
}

variable "db_username" {
  description = "The master username for the database."
  type        = string
  default     = "masteruser"
}

variable "allocated_storage" {
  description = "The allocated storage in gigabytes."
  type        = number
  default     = 100
}

variable "environment" {
  description = "The deployment environment (e.g., 'prod', 'staging')."
  type        = string
  default     = "prod"
}

locals {
  resource_prefix = "saas-${var.environment}-primary"
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "SaaS-Application"
    Component   = "PrimaryDatabase"
  }
}

resource "random_password" "master_password" {
  length           = 24
  special          = true
  override_special = "!#$%&()*+,-./:;<=>?@[]^_`{|}~"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${local.resource_prefix}-rds-credentials"
  description = "Credentials for the primary RDS PostgreSQL instance."
  tags        = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.master_password.result
    engine   = "postgres"
    host     = aws_db_instance.primary.address
    port     = aws_db_instance.primary.port
    dbname   = var.db_name
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_kms_key" "db_storage" {
  description             = "KMS key for RDS primary database storage encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags                    = local.common_tags
}

resource "aws_db_subnet_group" "primary" {
  name       = "${local.resource_prefix}-sng"
  subnet_ids = var.database_subnets
  tags       = local.common_tags
}

resource "aws_security_group" "db" {
  name        = "${local.resource_prefix}-rds-sg"
  description = "Allow PostgreSQL traffic from the application layer"
  vpc_id      = var.vpc_id

  tags = local.common_tags
}

resource "aws_security_group_rule" "allow_app_ingress" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group