terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

variable "kms_key_deletion_window" {
  description = "Number of days before KMS key is permanently deleted"
  type        = number
  default     = 30
}

variable "secret_recovery_window_days" {
  description = "Number of days before secret is permanently deleted"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Environment = "production"
    Application = "database"
    ManagedBy   = "terraform"
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_kms_key" "secret" {
  description             = "KMS CMK for encrypting prod/database/password secret"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowSecretsManagerUse"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "secret" {
  name          = "alias/prod-database-password"
  target_key_id = aws_kms_key.secret.key_id
}

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"

  lifecycle {
    ignore_changes = [
      length,
      special,
      override_special,
    ]
  }
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "prod/database/password"
  description             = "Production database password consumed by Lambda function"
  kms_key_id              = aws_kms_key.secret.arn
  recovery_window_in_days = var.secret_recovery_window_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_policy" "db_password" {
  secret_arn = aws_secretsmanager_secret.db_password.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action   = "secretsmanager:*"
        Resource = "*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

output "secret_arn" {
  description = "ARN of the production database password secret"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "secret_name" {
  description = "Name of the production database password secret"
  value       = aws_secretsmanager_secret.db_password.name
}

output "kms_key_arn" {
  description = "ARN of the KMS CMK encrypting the secret"
  value       = aws_kms_key.secret.arn
}