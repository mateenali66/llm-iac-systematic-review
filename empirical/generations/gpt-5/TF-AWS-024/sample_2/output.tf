terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  description = "AWS region for SNS topic."
}

variable "oncall_email" {
  type        = string
  description = "On-call distribution list email address to subscribe to the SNS topic."
  validation {
    condition     = can(regex(".+@.+\\..+", var.oncall_email))
    error_message = "oncall_email must be a valid email address."
  }
}

resource "aws_sns_topic" "critical_alerts" {
  name              = "critical-alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name      = "critical-alerts"
    Purpose   = "Production incident notifications"
    ManagedBy = "terraform"
    Scope     = "alerts"
    Environment = "prod"
  }
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    sid     = "DenyNonTLS"
    effect  = "Deny"
    actions = ["sns:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [aws_sns_topic.critical_alerts.arn]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sns_topic_policy" "critical_alerts_policy" {
  arn    = aws_sns_topic.critical_alerts.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

resource "aws_sns_topic_subscription" "oncall_email" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = var.oncall_email
}