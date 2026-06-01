resource "aws_secretsmanager_secret" "prod_database_password" {
  name                    = "prod/database/password"
  description             = "Production database password for Lambda function"
  recovery_window_in_days = 0

  tags = {
    Name        = "prod/database/password"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}