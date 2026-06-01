provider "aws" {
  region = "us-west-2"
}

resource "aws_secretsmanager_secret" "database_password" {
  name = "prod/database/password"
  description = "Production database password for Lambda function"
}

resource "aws_secretsmanager_secret_version" "database_password_version" {
  secret_id     = aws_secretsmanager_secret.database_password.id
  secret_string = "INSERT_PRODUCTION_DATABASE_PASSWORD_HERE"
}

resource "aws_iam_policy" "secrets_manager_policy" {
  name        = "secrets-manager-policy"
  description = "Policy for accessing Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = aws_secretsmanager_secret.database_password.arn
      },
    ]
  })
}