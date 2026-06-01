resource "aws_secretsmanager_secret" "prod_db_password" {
  name                    = "prod/database/password"
  description             = "Production database password used by Lambda"
  recovery_window_in_days = 30

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
    Purpose     = "lambda-database-credentials"
  }
}