resource "aws_s3_bucket" "log_delivery" {
  bucket = var.bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id

  rule {
    id     = "transition-to-glacier-after-90-days"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

resource "aws_s3_bucket_policy" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id
  policy = data.aws_iam_policy_document.log_delivery.json
}

data "aws_iam_policy_document" "log_delivery" {
  statement {
    sid    = "AllowCloudFrontLogDelivery"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.log_delivery.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid    = "AllowELBLogDelivery"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.log_delivery.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

variable "bucket_name" {
  description = "Name of the S3 bucket for log delivery"
  type        = string
}