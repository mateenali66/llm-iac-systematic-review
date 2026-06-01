terraform {
  required_version = ">= 1.5.0"

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
  description = "AWS region to deploy resources into."
}

variable "oncall_email" {
  type        = string
  description = "Email address for the on-call distribution list to subscribe to the SNS topic."
  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.oncall_email))
    error_message = "Provide a valid email address for the on-call distribution list."
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "kms_sns" {
  statement {
    sid     = "EnableIAMUserPermissions"
    effect  = "Allow"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = ["*"]
  }

  statement {
    sid    = "AllowSNSUseOfKey"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = [
        "sns.${data.aws_region.current.name}.${data.aws_partition.current.dns_suffix}"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:sns:arn"
      values = [
        "arn:${data.aws_partition.current.partition}:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      ]
    }
  }
}

resource "aws_kms_key" "sns" {
  description             = "KMS CMK for encrypting SNS topic 'critical-alerts' messages at rest."
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms_sns.json

  tags = {
    Name        = "sns-critical-alerts-kms"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_alias" "sns" {
  name          = "alias/sns/critical-alerts"
  target_key_id = aws_kms_key.sns.key_id
}

resource "aws_sns_topic" "critical_alerts" {
  name              = "critical-alerts"
  kms_master_key_id = aws_kms_key.sns.arn

  tags = {
    Name        = "critical-alerts"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    sid     = "AllowAccountManagement"
    effect  = "Allow"
    actions = ["sns:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = [aws_sns_topic.critical_alerts.arn]
  }

  statement {
    sid     = "AllowCloudWatchToPublish"
    effect  = "Allow"
    actions = ["sns:Publish"]
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    resources = [aws_sns_topic.critical_alerts.arn]
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alarm:*"
      ]
    }
  }

  statement {
    sid     = "AllowEventBridgeToPublish"
    effect  = "Allow"
    actions = ["sns:Publish"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    resources = [aws_sns_topic.critical_alerts.arn]
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/*"
      ]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["sns:*"]
    principals {
      type        = "AWS"
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

resource "aws_sns_topic_policy" "critical_alerts" {
  arn    = aws_sns_topic.critical_alerts.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

resource "aws_sns_topic_subscription" "oncall_email" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = var.oncall_email
}