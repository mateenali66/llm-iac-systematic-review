provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "log_delivery" {
  bucket        = "my-log-delivery-bucket"
  force_destroy = true

  lifecycle_rule {
    enabled = true

    noncurrent_version_transition {
      days          = 90
      storage_class = "GLACIER"
    }

    noncurrent_version_expiration {
      days = 365
    }
  }

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
}

resource "aws_s3_bucket_policy" "log_delivery" {
  bucket = aws_s3_bucket.log_delivery.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudFrontLogsDelivery"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Identity <CloudFront-Origin-Identity>"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.log_delivery.arn}/*"
      },
      {
        Sid       = "AWSELBLogsDelivery"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::156058536743:role/ELBLogging"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.log_delivery.arn}/*"
      }
    ]
  })
}