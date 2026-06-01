resource "aws_s3_bucket" "log_delivery" {
  bucket = var.bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_ownership_controls" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id
  acl    = "log-delivery-write"
  depends_on = [aws_s3_bucket_ownership_controls.log_delivery]
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

    filter {
      prefix = ""
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

variable "bucket_name" {
  description = "Name of the S3 bucket for log delivery"
  type        = string
}