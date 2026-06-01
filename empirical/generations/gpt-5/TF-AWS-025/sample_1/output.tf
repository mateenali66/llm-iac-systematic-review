terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.1"
    }
  }
}

provider "aws" {}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  resolved_bucket_name = var.bucket_name != "" ? var.bucket_name : "logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}-${random_id.suffix.hex}"
  elb_logs_prefix      = "elb/AWSLogs/${data.aws_caller_identity.current.account_id}/"
  cloudfront_prefix    = "cloudfront/"
  tags                 = merge({ ManagedBy = "Terraform" }, var.tags)
}

resource "aws_s3_bucket" "this" {
  bucket = local.resolved_bucket_name

  tags = local.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "this" {
  bucket = aws_s3_bucket.this.id
  acl    = "log-delivery-write"

  depends_on = [aws_s3_bucket_ownership_controls.this]
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "transition-logs-to-glacier-after-90-days"
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
  }
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid     = "AllowELBLogDelivery"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["elasticloadbalancing.amazonaws.com"]
    }
    resources = ["${aws_s3_bucket.this.arn}/${local.elb_logs_prefix}*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:elasticloadbalancing:*:${data.aws_caller_identity.current.account_id}:loadbalancer/*"]
    }
  }

  statement {
    sid     = "AllowELBLogDeliveryCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["elasticloadbalancing.amazonaws.com"]
    }
    resources = [aws_s3_bucket.this.arn]
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

variable "bucket_name" {
  description = "Optional explicit name for the S3 bucket. Must be globally unique. If empty, a name will be generated."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to created resources."
  type        = map(string)
  default     = {}
}