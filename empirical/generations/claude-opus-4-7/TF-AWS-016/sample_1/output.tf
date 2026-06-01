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

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "recovery_window_in_days" {
  description = "Number of days that AWS Secrets Manager waits before deleting the secret"
  type        = number
  default     = 30

  validation {
    condition     = var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30
    error_message = "Recovery window must be between 7 and 30 days."
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_kms_key" "secrets_manager" {
  description             = "KMS key for encrypting Secrets Manager secrets for production database"
  deletion_window_in_days = 30
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
        Sid    = "AllowSecretsManagerService"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "prod-database-password-kms"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_alias" "secrets_manager" {
  name          = "alias/prod-database-password"
  target_key_id = aws_kms_key.secrets_manager.key_id
}

resource "random_password" "database_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "aws_secretsmanager_secret" "database_password" {
  name                    = "prod/database/password"
  description             = "Production database password used by Lambda function"
  kms_key_id              = aws_kms_key.secrets_manager.arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = {
    Name        = "prod-database-password"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Application = "lambda"
  }
}

resource "aws_secretsmanager_secret_version" "database_password" {
  secret_id     = aws_secretsmanager_secret.database_password.id
  secret_string = jsonencode({
    password = random_password.database_password.result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_policy" "database_password" {
  secret_arn = aws_secretsmanager_secret.database_password.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyNonTLSAccess"
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
  description = "ARN of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.database_password.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.database_password.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = aws_kms_key.secrets_manager.arn
}