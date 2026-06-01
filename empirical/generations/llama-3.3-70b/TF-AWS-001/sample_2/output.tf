provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "prod_data" {
  bucket = "company-prod-data"
  acl    = "private"

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

resource "aws_s3_bucket_public_access_block" "prod_data" {
  bucket = aws_s3_bucket.prod_data.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "prod_data" {
  bucket = aws_s3_bucket.prod_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyIncorrectEncryptionHeader"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource = aws_s3_bucket.prod_data.arn
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
        }
      },
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource = aws_s3_bucket.prod_data.arn
        Condition = {
          Null = {
            "s3:x-amz-server-side-encryption" = "true"
          }
        }
      },
    ]
  })
}

resource "aws_s3_bucket_logging" "prod_data" {
  bucket = aws_s3_bucket.prod_data.id

  target_bucket = aws_s3_bucket.prod_data.id
  target_prefix = "log/"
}

resource "aws_s3_bucket_lifecycle_configuration" "prod_data" {
  bucket = aws_s3_bucket.prod_data.id

  rule {
    id     = "log"
    filter {
      prefix = "log/"
    }
    status = "Enabled"

    expiration {
      days = 365
    }
  }

  rule {
    id     = "config"
    filter {
      prefix = "config/"
    }
    status = "Enabled"

    expiration {
      days = 730
    }
  }
}