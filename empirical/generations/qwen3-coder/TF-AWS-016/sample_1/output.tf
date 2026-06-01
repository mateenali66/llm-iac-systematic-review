resource "aws_secretsmanager_secret" "prod_database_password" {
  name        = "prod/database/password"
  description = "Production database password for Lambda function access"

  tags = {
    Environment = "production"
    Service     = "database"
  }
}

resource "aws_secretsmanager_secret_version" "prod_database_password_version" {
  secret_id     = aws_secretsmanager_secret.prod_database_password.id
  secret_string = "initial-placeholder-password-change-in-aws-console"
}