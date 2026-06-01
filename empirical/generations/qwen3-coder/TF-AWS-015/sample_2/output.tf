resource "aws_kms_key" "pii_encryption_key" {
  description             = "KMS key for encrypting customer PII data in S3"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_key_policy.json
}

resource "aws_kms_alias" "pii_encryption_key_alias" {
  name          = "alias/pii-encryption-key"
  target_key_id = aws_kms_key.pii_encryption_key.key_id
}

data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow application role to use the key"
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
  }
}

data "aws_caller_identity" "current" {}

variable "application_role_arn" {
  description = "ARN of the application IAM role that will use this KMS key"
  type        = string
}