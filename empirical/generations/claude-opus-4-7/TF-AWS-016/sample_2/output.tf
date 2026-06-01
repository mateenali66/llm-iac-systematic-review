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
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "recovery_window_days" {
  description = "Number of days AWS Secrets Manager waits before deleting the secret"
  type        = number
  default     = 30

  validation {
    condition     = var.recovery_window_days >= 7 && var.recovery_window_days <= 30
    error_message = "Recovery window must be between 7 and 30 days."
  }
}

variable "lambda_role_arn" {
  description = "ARN of the Lambda execution role that needs access to the secret"
  type        = string
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_kms_key" "secrets" {
  description             = "KMS CMK for encrypting Secrets Manager secret prod/database/password"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  is_enabled              = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowSecretsManagerUseOfKey"
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
      },
      {
        Sid    = "AllowLambdaRoleToDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = var.lambda_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "secrets-prod-database-password-cmk"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/secrets/prod-database-password"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "prod/database/password"
  description             = "Production database password consumed by Lambda function"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = var.recovery_window_days

  tags = {
    Name        = "prod-database-password"
    Environment = var.environment
    ManagedBy   = "terraform"
    Sensitive   = "true"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "db_admin"
    password = random_password.db_password.result
  })

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
        Sid    = "AllowLambdaReadAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.lambda_role_arn
        }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
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
  value       = aws_secretsmanager_secret.db_password.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.db_password.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for secret encryption"
  value       = aws_kms_key.secrets.arn
}