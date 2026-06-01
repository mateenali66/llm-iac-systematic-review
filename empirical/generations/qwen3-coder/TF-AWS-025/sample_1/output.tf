resource "aws_s3_bucket" "log_bucket" {
  bucket = "prod-log-delivery-bucket-${random_string.suffix.result}"
  acl    = "log-delivery-write"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "transition_to_glacier"
    enabled = true

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  tags = {
    Name        = "LogDeliveryBucket"
    Environment = "production"
    Purpose     = "CloudFront and ELB access logs"
  }
}

resource "aws_s3_bucket_public_access_block" "log_bucket_block" {
  bucket = aws_s3_bucket.log_bucket.id

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