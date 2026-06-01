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
  description = "Email distribution list address for on-call incident notifications."
  type        = string
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default = {
    Environment = "production"
    Service     = "incident-management"
    ManagedBy   = "terraform"
    Owner       = "sre"
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_kms_key" "sns" {
  description             = "KMS CMK for encrypting SNS topic 'critical-alerts'"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccountAdmin"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowSNSUseOfTheKey"
        Effect    = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      },
      {
        Sid       = "AllowCloudWatchAlarmsUseOfTheKey"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
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
        Sid       = "AllowAccountOwnerFullManagement"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action = [
          "SNS:Publish",
          "SNS:Subscribe",
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:ListSubscriptionsByTopic",
          "SNS:DeleteTopic",
          "SNS:AddPermission",
          "SNS:RemovePermission"
        ]
        Resource = aws_sns_topic.critical_alerts.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
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

  confirmation_timeout_in_minutes = 5
}

output "sns_topic_arn" {
  description = "ARN of the critical-alerts SNS topic."
  value       = aws_sns_topic.critical_alerts.arn
}

output "sns_topic_name" {
  description = "Name of the critical-alerts SNS topic."
  value       = aws_sns_topic.critical_alerts.name
}

output "sns_kms_key_arn" {
  description = "ARN of the KMS key used for SNS topic encryption."
  value       = aws_kms_key.sns.arn
}