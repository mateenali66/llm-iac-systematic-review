data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_kms_key" "company_prod_data" {
  description             = "CMK for S3 bucket company-prod-data (production logs and backups)"
  enable_key_rotation     = true
  multi_region            = false
  policy                  = data.aws_iam_policy_document.kms_company_prod_data.json

  tags = {
    Name             = "company-prod-data-kms"
    Environment      = "production"
    ManagedBy        = "terraform"
    DataClassification = "confidential"
  }
}

resource "aws_kms_alias" "company_prod_data" {
  name          = "alias/company-prod-data-s3"
  target_key_id = aws_kms_key.company_prod_data.key_id
}

data "aws_iam_policy_document" "kms_company_prod_data" {
  statement {
    sid     = "EnableIAMUserPermissions"
    effect  = "Allow"
    actions = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid     = "AllowS3UseOfTheKeyForBucket"
    effect  = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
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

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${data.aws_region.current.name}.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values   = ["arn:aws:s3:::company-prod-data/*"]
    }
  }
}

resource "aws_s3_bucket" "company_prod_data" {
  bucket        = "company-prod-data"
  force_destroy = false

  tags = {
    Name               = "company-prod-data"
    Environment        = "production"
    ManagedBy          = "terraform"
    DataClassification = "confidential"
  }
}

resource "aws_s3_bucket_ownership_controls" "company_prod_data" {
  bucket = aws_s3_bucket.company_prod_data.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "company_prod_data" {
  bucket = aws_s3_bucket.company_prod_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "company_prod_data" {
  bucket = aws_s3_bucket.company_prod_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "company_prod_data" {
  bucket = aws_s3_bucket.company_prod_data.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.company_prod_data.arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "company_prod_data" {
  bucket = aws_s3_bucket.company_prod_data.id

  rule {
    id     = "default-lifecycle"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER_IR"
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "company_prod_data_bucket_policy" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.company_prod_data.arn,
      "${aws_s3_bucket.company_prod_data.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid     = "DenyUnencryptedObjectUploads"
    effect  = "Deny"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:InitiateMultipartUpload",
      "s3:UploadPart",
      "s3:UploadPartCopy",
      "s3:CompleteMultipartUpload"
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = ["${aws_s3_bucket.company_prod_data.arn}/*"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }

  statement {
    sid     = "DenyIncorrectKMSKey"
    effect  = "Deny"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:InitiateMultipartUpload",
      "s3:UploadPart",
      "s3:UploadPartCopy",
      "s3:CompleteMultipartUpload"
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = ["${aws_s3_bucket.company_prod_data.arn}/*"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [aws_kms_key.company_prod_data.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "company_prod_data" {
  bucket = aws_s3_bucket.company_prod_data.id
  policy = data.aws_iam_policy_document.company_prod_data_bucket_policy.json
}