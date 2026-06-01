resource "random_pet" "bucket_suffix" {
  length = 2
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_elb_service_account" "current" {}

resource "aws_s3_bucket" "log_delivery" {
  bucket = "log-delivery-bucket-${random_pet.bucket_suffix.id}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_ownership_controls" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id

  rule {
    id     = "log-transition-and-expiration"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "logging.cloudfront.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.log_delivery.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:cloudfront::${