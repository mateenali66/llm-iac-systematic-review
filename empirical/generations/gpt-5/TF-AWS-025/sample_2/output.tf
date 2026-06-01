terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region for the provider"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Globally unique name for the S3 bucket receiving CloudFront and ELB access logs"
  type        = string
}

variable "cf_logs_prefix" {
  description = "Prefix within the bucket for CloudFront access logs"
  type        = string
  default     = "cloudfront-logs/"
}

variable "elb_logs_prefix" {
  description = "Prefix within the bucket for ELB/ALB/NLB access logs"
  type        = string
  default     = "elb-logs/"
}

variable "force_destroy" {
  description = "Force destroy the bucket even if it contains objects"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all created resources"
  type        = map(string)
  default     = {}
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  cf_logs_resource_arn  = "arn:${local.partition}:s3:::${var.bucket_name}/${var.cf_logs_prefix}*"
  elb_logs_resource_arn = "arn:${local.partition}:s3:::${var.bucket_name}/${var.elb_logs_prefix}AWSLogs/${local.account_id}/*"
}

resource "aws_s3_bucket" "logs" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = var.bucket_name
  })
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
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

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "transition-logs-to-glacier-90-days"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }
  }

  depends_on = [aws_s3_bucket_versioning.logs]
}

data "aws_iam_policy_document" "logs_bucket" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
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
    resources = [
      local.elb_logs_resource_arn
    ]
    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:elasticloadbalancing:*:${local.account_id}:loadbalancer/*"]
    }
  }

  statement {
    sid     = "AllowCloudFrontLogDelivery"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      local.cf_logs_resource_arn
    ]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:cloudfront::${local.account_id}:distribution/*"]
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.logs_bucket.json

  depends_on = [
    aws_s3_bucket_public_access_block.logs,
    aws_s3_bucket_ownership_controls.logs
  ]
}