terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "oncall_email" {
  description = "Email distribution list address subscribed to receive critical incident alerts."
  type        = string
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default = {
    Environment = "production"
    ManagedBy   = "terraform"
    Purpose     = "incident-notifications"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "sns" {
  description             = "KMS CMK used to encrypt the critical-alerts SNS topic"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccountPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid    = "AllowSNSUseOfKey"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchUseOfKey"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "sns" {
  name          = "alias/sns-critical-alerts"
  target_key_id = aws_kms_key.sns.key_id
}

resource "aws_sns_topic" "critical_alerts" {
  name              = "critical-alerts"
  display_name      = "Critical Alerts"
  kms_master_key_id = aws_kms_key.sns.id

  delivery_policy = jsonencode({
    http = {
      defaultHealthyRetryPolicy = {
        minDelayTarget     = 20
        maxDelayTarget     = 20
        numRetries         = 3
        numMaxDelayRetries = 0
        numNoDelayRetries  = 0
        numMinDelayRetries = 0
        backoffFunction    = "linear"
      }
      disableSubscriptionOverrides = false
    }
  })

  tags = var.tags
}

resource "aws_sns_topic_policy" "critical_alerts" {
  arn = aws_sns_topic.critical_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "critical-alerts-topic-policy"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.critical_alerts.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowAccountOwnerFullManagement"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "SNS:Publish",
          "SNS:Subscribe",
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:ListSubscriptionsByTopic",
          "SNS:AddPermission",
          "SNS:RemovePermission"
        ]
        Resource = aws_sns_topic.critical_alerts.arn
      },
      {
        Sid    = "AllowCloudWatchAlarmsToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.critical_alerts.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "oncall_email" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = var.oncall_email

  lifecycle {
    ignore_changes = [confirmation_timeout_in_minutes]
  }
}

output "sns_topic_arn" {
  description = "ARN of the critical-alerts SNS topic."
  value       = aws_sns_topic.critical_alerts.arn
}

output "sns_topic_name" {
  description = "Name of the critical-alerts SNS topic."
  value       = aws_sns_topic.critical_alerts.name
}

output "kms_key_arn" {
  description = "ARN of the KMS CMK encrypting the SNS topic."
  value       = aws_kms_key.sns.arn
}