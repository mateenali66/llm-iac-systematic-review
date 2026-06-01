data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

resource "aws_kms_key" "app_logs" {
  description             = "KMS CMK for encrypting CloudWatch Logs for /aws/app/prod"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EnableIAMUserPermissions"
        Effect   = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid      = "AllowCloudWatchLogsUseOfTheKey"
        Effect   = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.${data.aws_partition.current.dns_suffix}"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/app/prod"
          }
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "app-prod-logs-cmk"
    Application = "app"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "app_logs" {
  name          = "alias/app-prod-logs"
  target_key_id = aws_kms_key.app_logs.key_id
}

resource "aws_cloudwatch_log_group" "app_prod" {
  name              = "/aws/app/prod"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.app_logs.arn
  skip_destroy      = true

  tags = {
    Name        = "/aws/app/prod"
    Application = "app"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}