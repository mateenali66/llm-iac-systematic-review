data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

resource "aws_kms_key" "cw_logs" {
  description             = "KMS CMK for encrypting CloudWatch Logs for /aws/app/prod"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogsUseOfTheKey",
        Effect = "Allow",
        Principal = {
          Service = "logs.${data.aws_region.current.name}.${data.aws_partition.current.dns_suffix}"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource  = "*",
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = [
              "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/app/prod",
              "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/app/prod:*"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name        = "cloudwatch-logs-prod"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_alias" "cw_logs_alias" {
  name          = "alias/cloudwatch-logs/prod"
  target_key_id = aws_kms_key.cw_logs.key_id
}

resource "aws_cloudwatch_log_group" "app_prod" {
  name              = "/aws/app/prod"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.cw_logs.arn

  tags = {
    Name        = "/aws/app/prod"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}