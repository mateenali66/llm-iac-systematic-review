provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "log_delivery_bucket" {
  bucket        = "my-log-delivery-bucket"
  force_destroy = true

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

resource "aws_s3_bucket_policy" "log_delivery_bucket_policy" {
  bucket = aws_s3_bucket.log_delivery_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudFrontReadOnlyAccess"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Identity E2QKWML33VA4D"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.log_delivery_bucket.arn}/*"
      },
      {
        Sid       = "AWSELBReadOnlyAccess"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::127311923021:root"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.log_delivery_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "log_delivery_bucket_lifecycle" {
  bucket = aws_s3_bucket.log_delivery_bucket.id

  rule {
    id     = "log-lifecycle-rule"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}