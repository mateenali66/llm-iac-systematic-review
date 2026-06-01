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
  description = "ARN of the IAM role used by the application to access encrypted PII data"
  type        = string
}

variable "pii_bucket_name" {
  description = "Name of the S3 bucket storing customer PII"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., prod, staging)"
  type        = string
  default     = "prod"
}

variable "kms_key_deletion_window" {
  description = "Number of days to wait before deleting the KMS key"
  type        = number
  default     = 30

  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days."
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "pii_kms_key_policy" {
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
      "kms:DescribeKey"
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
      values   = ["arn:${data.aws_partition.current.partition}:s3:::${var.pii_bucket_name}"]
    }
  }

  statement {
    sid    = "AllowCloudWatchLogsForAuditing"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]

    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
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

resource "aws_kms_key" "pii_encryption" {
  description              = "Customer Managed Key for encrypting customer PII in S3 bucket ${var.pii_bucket_name}"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"

  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true
  rotation_period_in_days = 365

  multi_region            = false
  bypass_policy_lockout_safety_check = false

  policy = data.aws_iam_policy_document.pii_kms_key_policy.json

  tags = {
    Name             = "pii-s3-encryption-key"
    Environment      = var.environment
    DataClassification = "PII"
    Compliance       = "GDPR-CCPA"
    ManagedBy        = "Terraform"
  }
}

resource "aws_kms_alias" "pii_encryption" {
  name          = "alias/${var.environment}-customer-pii-s3"
  target_key_id = aws_kms_key.pii_encryption.key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt customer PII"
  value       = aws_kms_key.pii_encryption.arn
}

output "kms_key_id" {
  description = "ID of the KMS key used to encrypt customer PII"
  value       = aws_kms_key.pii_encryption.key_id
}

output "kms_key_alias" {
  description = "Alias of the KMS key used to encrypt customer PII"
  value       = aws_kms_alias.pii_encryption.name
}