resource "aws_secretsmanager_secret" "prod_db_password" {
  name                    = "prod/database/password"
  description             = "Production database password used by Lambda function"
  recovery_window_in_days = 30
  kms_key_id              = "alias/aws/secretsmanager"

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Purpose     = "lambda-database-access"
  }
}