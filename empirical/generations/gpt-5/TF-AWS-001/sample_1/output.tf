terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.41"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

locals {
  bucket_name = "company-prod-data"
  common_tags = {
    Environment = "production"
    Project     = "company-prod-data"
    ManagedBy   = "terraform"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "s3_company_prod_data" {
  description             = "CMK for encrypting S3 bucket objects in ${local.bucket_name}"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EnableIAMUserPermissions"
        Effect   = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid      = "AllowS3UseOfTheKeyForBucket"
        Effect   = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource  = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService"                     = "s3.${var.aws_region}.amazonaws.com"
            "kms:EncryptionContext:aws:s3:arn"   = "arn:aws:s3:::${local.bucket_name}/*"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_kms_alias" "s3_company_prod_data_alias" {
  name          = "alias/s3/${local.bucket_name}"
  target_key_id = aws_kms_key.s3_company_prod_data.key_id
}

resource "aws_s3_bucket" "company_prod_data" {
  bucket        = local.bucket_name
  force_destroy = false

  tags = local.common_tags
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
      kms_master_key_id = aws_kms_key.s3_company_prod_data.arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "company_prod_data" {
  bucket = aws_s3_bucket.company_prod_data.id

  rule {
    id     = "tiering-current-versions"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 180
      storage_class = "DEEP_ARCHIVE"
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "tiering-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 180
      storage_class   = "DEEP_ARCHIVE"
    }

    noncurrent_version_expiration {
      noncurrent_days = 730
    }
  }
}

resource "aws_s3_bucket_policy" "company_prod_data" {
  bucket = aws_s3_bucket.company_prod_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyInsecureTransport"
        Effect   = "Deny"
        Principal = "*"
        Action   = "s3:*"
        Resource = [
          aws_s3_bucket.company_prod_data.arn,
          "${aws_s3_bucket.company_prod_data.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid      = "DenyIncorrectSSEAlgorithmIfProvided"
        Effect   = "Deny"
        Principal = "*"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.company_prod_data.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
          Null = {
            "s3:x-amz-server-side-encryption" = "false"
          }
        }
      },
      {
        Sid      = "DenyWrongKmsKeyIfProvided"
        Effect   = "Deny"
        Principal = "*"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.company_prod_data.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.s3_company_prod_data.arn
          }
          Null = {
            "s3:x-amz-server-side-encryption-aws-kms-key-id" = "false"
          }
        }
      }
    ]
  })
}