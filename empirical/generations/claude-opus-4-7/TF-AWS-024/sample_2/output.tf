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

variable "environment" {
  description = "Deployment environment tag."
  type        = string
  default     = "production"
}

variable "kms_key_id" {
  description = "Optional KMS key ID/ARN for SNS topic encryption. If null, the AWS-managed key (alias/aws/sns) is used."
  type        = string
  default     = null
}

locals {
  topic_name = "critical-alerts"

  common_tags = {
    Name        = local.topic_name
    Environment = var.environment
    Purpose     = "production-incident-notifications"
    ManagedBy   = "terraform"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "critical_alerts" {
  name              = local.topic_name
  display_name      = "Critical Alerts"
  kms_master_key_id = var.kms_key_id != null ? var.kms_key_id : "alias/aws/sns"

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

  tags = local.common_tags
}

data "aws_iam_policy_document" "critical_alerts" {
  statement {
    sid    = "AllowOwnerFullControl"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }

    actions = [
      "SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
      "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic",
      "SNS:Publish",
    ]

    resources = [aws_sns_topic.critical_alerts.arn]
  }

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.critical_alerts.arn]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AllowCloudWatchAlarmsPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.critical_alerts.arn]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "critical_alerts" {
  arn    = aws_sns_topic.critical_alerts.arn
  policy = data.aws_iam_policy_document.critical_alerts.json
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
  description = "ARN of the critical alerts SNS topic."
  value       = aws_sns_topic.critical_alerts.arn
}

output "sns_topic_name" {
  description = "Name of the critical alerts SNS topic."
  value       = aws_sns_topic.critical_alerts.name
}