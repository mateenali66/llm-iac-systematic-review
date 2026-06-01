terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "application_role_arn" {
  description = "ARN of the IAM role used by the application that requires access to the KMS key."
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket that will store customer PII encrypted with this KMS key."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. prod, staging)."
  type        = string
  default     = "prod"
}

variable "kms_key_alias" {
  description = "Alias for the KMS key (without the 'alias/' prefix)."
  type        = string
  default     = "customer-pii-s3"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "kms_key" {
  statement {
    sid    = "EnableRootAccountAdministration"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowApplicationRoleToUseKey"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [var.application_role_arn]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${data.aws_region.current.name}.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values   = ["arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket_name}"]
    }
  }

  statement {
    sid    = "AllowApplicationRoleToCreateGrants"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [var.application_role_arn]
    }

    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
    ]

    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions   = ["kms:*"]
    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_kms_key" "pii" {
  description              = "CMK for encrypting customer PII stored in S3 bucket ${var.s3_bucket_name}"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  deletion_window_in_days  = 30
  enable_key_rotation      = true
  rotation_period_in_days  = 365
  multi_region             = false
  is_enabled               = true
  bypass_policy_lockout_safety_check = false

  policy = data.aws_iam_policy_document.kms_key.json

  tags = {
    Name        = "customer-pii-s3"
    Environment = var.environment
    DataClass   = "PII"
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_alias" "pii" {
  name          = "alias/${var.kms_key_alias}"
  target_key_id = aws_kms_key.pii.key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt customer PII."
  value       = aws_kms_key.pii.arn
}

output "kms_key_id" {
  description = "ID of the KMS key used to encrypt customer PII."
  value       = aws_kms_key.pii.key_id
}

output "kms_key_alias_arn" {
  description = "ARN of the KMS key alias."
  value       = aws_kms_alias.pii.arn
}