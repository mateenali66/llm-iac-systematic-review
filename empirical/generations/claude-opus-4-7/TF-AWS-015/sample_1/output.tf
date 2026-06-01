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

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", var.application_role_arn))
    error_message = "application_role_arn must be a valid IAM role ARN."
  }
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket whose PII objects will be encrypted with this key."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., prod, staging)."
  type        = string
  default     = "prod"
}

variable "key_alias" {
  description = "Alias name for the KMS key (without the 'alias/' prefix)."
  type        = string
  default     = "pii-s3-encryption"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "pii_kms_key" {
  # Root account administrative access (required to prevent key lockout)
  statement {
    sid    = "EnableRootAccountAdmin"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Application role: cryptographic operations only
  statement {
    sid    = "AllowApplicationRoleUseOfKey"
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

    # Restrict key usage to S3 service in this account/region
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${data.aws_region.current.name}.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # Application role: grant management (needed for some S3 integrations)
  statement {
    sid    = "AllowApplicationRoleGrantManagement"
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
}

resource "aws_kms_key" "pii" {
  description              = "Customer PII encryption key for S3 bucket ${var.s3_bucket_arn}"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  deletion_window_in_days  = 30
  enable_key_rotation      = true
  rotation_period_in_days  = 365
  multi_region             = false
  is_enabled               = true

  policy = data.aws_iam_policy_document.pii_kms_key.json

  tags = {
    Name             = var.key_alias
    Environment      = var.environment
    DataClassification = "PII"
    Purpose          = "S3-PII-Encryption"
    ManagedBy        = "Terraform"
  }
}

resource "aws_kms_alias" "pii" {
  name          = "alias/${var.key_alias}"
  target_key_id = aws_kms_key.pii.key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt PII in S3."
  value       = aws_kms_key.pii.arn
}

output "kms_key_id" {
  description = "ID of the KMS key used to encrypt PII in S3."
  value       = aws_kms_key.pii.key_id
}

output "kms_key_alias" {
  description = "Alias of the KMS key."
  value       = aws_kms_alias.pii.name
}