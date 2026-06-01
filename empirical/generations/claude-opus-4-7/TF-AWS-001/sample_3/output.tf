terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "bucket_name" {
  description = "Name of the S3 bucket for production data"
  type        = string
  default     = "company-prod-data"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "production"
}

variable "log_retention_days" {
  description = "Number of days to retain noncurrent object versions"
  type        = number
  default     = 365
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "s3" {
  description             = "KMS key for encrypting ${var.bucket_name} S3 bucket"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.bucket_name}-kms"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.bucket_name}"
  target_key_id = aws_kms_key.s3.key_id
}

resource "aws_s3_bucket" "logs_access" {
  bucket        = "${var.bucket_name}-access-logs"
  force_destroy = false

  tags = {
    Name        = "${var.bucket_name}-access-logs"
    Environment = var.environment
    Purpose     = "s3-access-logs"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "logs_access" {
  bucket                  = aws_s3_bucket.logs_access.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs_access" {
  bucket = aws_s3_bucket.logs_access.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs_access" {
  bucket = aws_s3_bucket.logs_access.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "logs_access" {
  bucket = aws_s3_bucket.logs_access.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs_access" {
  bucket = aws_s3_bucket.logs_access.id

  rule {
    id     = "expire-old-access-logs"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 730
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket" "main" {
  bucket        = var.bucket_name
  force_destroy = false

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
    DataClass   = "sensitive"
    Compliance  = "required"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket                  = aws_s3_bucket.main.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_logging" "main" {
  bucket = aws_s3_bucket.main.id

  target_bucket = aws_s3_bucket.logs_access.id
  target_prefix = "s3-access-logs/${var.bucket_name}/"
}

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "transition-and-expire-noncurrent"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"