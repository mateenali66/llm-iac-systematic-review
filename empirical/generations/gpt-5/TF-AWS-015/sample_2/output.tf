terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "app_role_arn" {
  description = "ARN of the application's IAM role that is allowed to use the KMS key"
  type        = string
  validation {
    condition     = can(regex("^arn:aws(-[a-z]+)?:iam::\\d{12}:role\\/.+", var.app_role_arn))
    error_message = "app_role_arn must be a valid IAM role ARN."
  }
}

variable "bucket_name" {
  description = "Name of the S3 bucket to store customer PII"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be a valid S3 bucket name."
  }
}

variable "kms_alias" {
  description = "Alias for the KMS key"
  type        = string
  default     = "alias/pii-s3-data"
  validation {
    condition     = startswith(var.kms_alias, "alias/")
    error_message = "kms_alias must start with 'alias/'."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

resource "aws_s3_bucket" "pii" {
  bucket = var.bucket_name

  tags = merge({
    Name        = var.bucket_name
    ManagedBy   = "Terraform"
    DataClass   = "PII"
  }, var.tags)

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "pii" {
  bucket = aws_s3_bucket.pii.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "pii" {
  bucket = aws_s3_bucket.pii.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_kms_key" "pii" {
  description             = "KMS key for encrypting customer PII in S3 bucket ${aws_s3_bucket.pii.id}"
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EnableRootPermissions"
        Effect   = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowAppRoleUseOfTheKeyViaS3ForBucket"
        Effect = "Allow"
        Principal = {
          AWS = var.app_role_arn
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
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
            "kms:ViaService"    = "s3.${data.aws_region.current.name}.amazonaws.com"
          }
          StringLike = {
            "kms:EncryptionContext:aws:s3:arn" = "arn:${data.aws_partition.current.partition}:s3:::${aws_s3_bucket.pii.id}/*"
          }
        }
      }
    ]
  })

  tags = merge({
    Name      = "pii-s3-kms-key"
    ManagedBy = "Terraform"
    DataClass = "PII"
  }, var.tags)

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "pii" {
  name          = var.kms_alias
  target_key_id = aws_kms_key.pii.key_id
}

resource "aws_s3_bucket_versioning" "pii" {
  bucket = aws_s3_bucket.pii.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pii" {
  bucket = aws_s3_bucket.pii.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.pii.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_policy" "pii" {
  bucket = aws_s3_bucket.pii.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyInsecureTransport"
        Effect   = "Deny"
        Principal = "*"
        Action   = "s3:*"
        Resource = [
          aws_s3_bucket.pii.arn,
          "${aws_s3_bucket.pii.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = false
          }
        }
      },
      {
        Sid      = "DenyUnEncryptedObjectUploads"
        Effect   = "Deny"
        Principal = "*"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.pii.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid      = "DenyIncorrectKMSKey"
        Effect   = "Deny"
        Principal = "*"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.pii.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.pii.arn
          }
        }
      }
    ]
  })
}