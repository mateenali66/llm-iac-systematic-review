provider "aws" {
  region = "us-west-2"
}

resource "aws_secretsmanager_secret" "prod_database_password" {
  name = "prod/database/password"
  description = "Production database password for Lambda function"
}

resource "aws_secretsmanager_secret_version" "prod_database_password_version" {
  secret_id     = aws_secretsmanager_secret.prod_database_password.id
  secret_string = "INSERT_PRODUCTION_DATABASE_PASSWORD_HERE"
}

resource "aws_iam_policy" "lambda_secrets_manager_policy" {
  name        = "lambda-secrets-manager-policy"
  description = "Policy for Lambda function to access Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = aws_secretsmanager_secret.prod_database_password.arn
      },
    ]
  })
}