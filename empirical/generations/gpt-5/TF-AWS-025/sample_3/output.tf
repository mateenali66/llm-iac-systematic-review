variable "bucket_name" {
  description = "Name of the S3 bucket for log delivery."
  type        = string
}

variable "account_id" {
  description = "AWS account ID receiving ELB logs."
  type        = string
}

variable "cloudfront_logs_prefix" {
  description = "Prefix for CloudFront access logs."
  type        = string
  default     = "cloudfront-logs"
}

variable "elb_logs_prefix" {
  description = "Top-level prefix for ELB logs (ELB will append AWSLogs/<account-id>/...)."
  type        = string
  default     = "AWSLogs"
}

resource "aws_s3_bucket" "logs" {
  bucket        = var.bucket_name
  force_destroy = false

  tags = {
    Name        = var.bucket_name
    ManagedBy   = "Terraform"
    Purpose     = "CF-and-ELB-Access-Logs"
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "transition-to-glacier-90-days"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "log_delivery" {
  statement {
    sid     = "AWSLogDeliveryWriteELB"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.logs.id}/${var.elb_logs_prefix}/${var.account_id}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid     = "AWSLogDeliveryWriteCloudFront"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.logs.id}/${var.cloudfront_logs_prefix}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid     = "AWSLogDeliveryGetBucketAcl"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    resources = ["arn:aws:s3:::${aws_s3_bucket.logs.id}"]
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.logs.id}",
      "arn:aws:s3:::${aws_s3_bucket.logs.id}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.log_delivery.json
}