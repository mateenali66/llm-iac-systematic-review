variable "application_iam_role_name" {
  description = "The name of the IAM role for the application that will use this KMS key."
  type        = string
}

variable "key_admin_role_arns" {
  description = "A list of IAM Role ARNs that should have administrative permissions on this key."
  type        = list(string)
  default     = []
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "pii_key_policy" {
  statement {
    sid = "EnableRootAndAdmins"
    actions = [
      "kms:*"
    ]
    resources = ["*"]
    principals {
      type = "AWS"
      identifiers = distinct(concat(
        ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"],
        var.key_admin_role_arns
      ))
    }
  }

  statement {
    sid = "AllowApplicationRoleUsage"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.application_iam_role_name}"]
    }
  }

  statement {
    sid = "AllowS3ToUseKeyForSSE"
    actions = [
      "kms:GenerateDataKey"
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key" "pii_data" {
  description             = "KMS key for encrypting customer PII in S3"
  policy                  = data.aws_iam_policy_document.pii_key_policy.json
  deletion_window_in_days = 7
  enable_key_rotation     = true
  multi_region            = false

  tags = {
    Name        = "pii-data-key"
    Purpose     = "PII Encryption"
    ManagedBy   = "Terraform"
    Environment = "Production"
  }
}

resource "aws_kms_alias" "pii_data" {
  name          = "alias/pii-data-key"
  target_key_id = aws_kms_key.pii_data.key_id
}