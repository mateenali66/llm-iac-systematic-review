terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_kms_key" "log_group" {
  description             = "KMS key for encrypting CloudWatch log group /aws/app/prod"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableIAMUserPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${data.aws_region.current.name}.amazonaws.com" }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/app/prod"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "cloudwatch-logs-app-prod"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "log_group" {
  name          = "alias/cloudwatch-logs-app-prod"
  target_key_id = aws_kms_key.log_group.key_id
}

resource "aws_cloudwatch_log_group" "app_prod" {
  name              = "/aws/app/prod"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.log_group.arn

  tags = {
    Name        = "/aws/app/prod"
    Environment = "production"
    Application = "app"
    ManagedBy   = "terraform"
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app_prod.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app_prod.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the log group"
  value       = aws_kms_key.log_group.arn
}