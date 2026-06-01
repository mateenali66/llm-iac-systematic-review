terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "bucket_name" {
  description = "Name of the S3 bucket storing PII."
  type        = string
}

variable "app_role_arn" {
  description = "IAM Role ARN of the application that can use the KMS key."
  type        = string
}

variable "key_admin_arns" {
  description = "List of IAM principal ARNs that can administer the key (not use it). If empty, defaults to account root."
  type        = list(string)
  default     = []
}

variable "kms_alias" {
  description = "Alias for the KMS key."
  type        = string
  default     = "alias/pii-s3-kms"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_root_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  key_admin_arns   = length(var.key_admin_arns) > 0 ? var.key_admin_arns : [local.account_root_arn]
}

resource "aws_s3_bucket" "pii" {
  bucket        = var.bucket_name
  force_destroy = false

  tags = {
    Name        = var.bucket_name
    Environment = "prod"
    DataType    = "PII"
  }
}

resource "aws_s3_bucket_public_access_block" "pii" {
  bucket = aws_s3_bucket.pii.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "pii" {
  bucket = aws_s3_bucket.pii.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "pii" {
  bucket = aws_s3_bucket.pii.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid     = "AllowKeyAdministration"
    effect  = "Allow"
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:ReplicateKey",
      "kms:UpdateAlias",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:PutKeyPolicy"
    ]

    principals {
      type        = "AWS"
      identifiers = local.key_admin_arns
    }

    resources = ["*"]
  }

  statement {
    sid     = "AllowAppRoleUseForS3Only"
    effect  = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    principals {
      type        = "AWS"
      identifiers = [var.app_role_arn]
    }

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${data.aws_region.current.name}.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values   = ["arn:aws:s3:::${var.bucket_name}/*"]
    }
  }

  statement {
    sid     = "AllowAppRoleToCreateGrantsForAWSResources"
    effect  = "Allow"
    actions = [
      "kms:CreateGrant"
    ]

    principals {
      type        = "AWS"
      identifiers = [var.app_role_arn]
    }

    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${data.aws_region.current.name}.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "pii" {
  description             = "KMS key for encrypting customer PII in S3"
  key_usage               = "ENCRYPT_DECRYPT"
  key_spec                = "SYMMETRIC_DEFAULT"
  enable_key_rotation     = true
  is_enabled              = true
  multi_region            = false
  policy                  = data.aws_iam_policy_document.kms_key_policy.json
  deletion_window_in_days = 30

  tags = {
    Name        = "pii-s3-kms"
    Environment = "prod"
    DataType    = "PII"
  }
}

resource "aws_kms_alias" "pii" {
  name          = var.kms_alias
  target_key_id = aws_kms_key.pii.key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pii" {
  bucket = aws_s3_bucket.pii.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.pii.arn
    }
    bucket_key_enabled = true
  }
}

data "aws_iam_policy_document" "pii_bucket_policy" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.pii.arn,
      "${aws_s3_bucket.pii.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid     = "DenyUnEncryptedObjectUploads"
    effect  = "Deny"
    actions = ["s3:PutObject"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = ["${aws_s3_bucket.pii.arn}/*"]

    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["true"]
    }
  }

  statement {
    sid     = "DenyIncorrectEncryptionHeader"
    effect  = "Deny"
    actions = ["s3:PutObject"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = ["${aws_s3_bucket.pii.arn}/*"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }

  statement {
    sid     = "DenyUsingWrongKMSKey"
    effect  = "Deny"
    actions = ["s3:PutObject"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = ["${aws_s3_bucket.pii.arn}/*"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [aws_kms_key.pii.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "pii" {
  bucket = aws_s3_bucket.pii.id
  policy = data.aws_iam_policy_document.pii_bucket_policy.json
}