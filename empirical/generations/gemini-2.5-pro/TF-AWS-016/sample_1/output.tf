resource "aws_kms_key" "secrets_manager_key" {
  description             = "KMS key for encrypting Secrets Manager secrets"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-default-1"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
    ]
  })

  tags = {
    Name        = "secrets-manager-key"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_alias" "secrets_manager_key_alias" {
  name          = "alias/secrets-manager-key"
  target_key_id = aws_kms_key.secrets_manager_key.id
}

data "aws_caller_identity" "current" {}

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "prod/database/password"
  description             = "Production database password"
  kms_key_id              = aws_kms_key.secrets_manager_key.id
  recovery_window_in_days = 7

  tags = {
    Name        = "prod-database-password"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result

  lifecycle {
    ignore_changes = [
      secret_string,
    ]
  }
}