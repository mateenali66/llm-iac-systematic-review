resource "aws_s3_bucket" "log_delivery" {
  bucket = "prod-log-delivery-${random_string.suffix.result}"
}

resource "aws_s3_bucket_ownership_controls" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "log_delivery" {
  depends_on = [aws_s3_bucket_ownership_controls.log_delivery]
  bucket = aws_s3_bucket.log_delivery.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_lifecycle_configuration" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
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

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}