resource "aws_s3_bucket" "log_delivery" {
  bucket = "log-delivery-bucket"
  acl    = "log-delivery-write"

  lifecycle_rule {
    id      = "transition_to_glacier"
    enabled = true

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  tags = {
    Name        = "Log Delivery Bucket"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_public_access_block" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}