provider "aws" {
  region = var.aws_region
}

locals {
  name_prefix = "saas-prod"
  tags = {
    Environment = "production"
    Application = "saas-primary"
    ManagedBy   = "terraform"
  }
}

resource "random_password" "master_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${local.name_prefix}-db-credentials"
  description = "Credentials for the primary RDS database"
  tags        = local.tags
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
    db_arn   = aws_db_instance.primary.arn
  })

  lifecycle {
    ignore_changes = [
      secret_string,
    ]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr