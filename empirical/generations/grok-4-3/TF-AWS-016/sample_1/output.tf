resource "aws_secretsmanager_secret" "prod_database_password" {
  name                    = "prod/database/password"
  description             = "Production database password consumed by Lambda"
  recovery_window_in_days = 30
  kms_key_id              = aws_kms_key.secrets.arn

  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
    Purpose     = "lambda-db-password"
  }
}

resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/prod/secretsmanager"
  target_key_id = aws_kms_key.secrets.key_id
}