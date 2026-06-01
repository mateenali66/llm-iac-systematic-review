provider "aws" {
  region = "us-east-1"
}

resource "random_pet" "bucket_name" {
  length = 2
}

resource "aws_s3_bucket" "origin" {
  bucket = "origin-bucket-${random_pet.bucket_name.id}"
}

resource "aws_s3_bucket_ownership_controls" "origin" {
  bucket = aws_s3_bucket.origin.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "origin" {
  bucket = aws_s3_bucket.origin.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "s3-oac-${aws_s3_bucket.origin.bucket}"
  description                       = "Origin Access Control for S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions    = ["s3:GetObject"]
    resources  = ["${aws_s3_bucket.origin.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "origin_policy" {
  bucket = aws_s3_bucket.origin.id
  policy = data.aws_iam_policy_document.s3_policy.json
  depends_