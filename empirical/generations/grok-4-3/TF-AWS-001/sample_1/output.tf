resource "aws_kms_key" "s3" {
  description             = "KMS key for company-prod-data bucket"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags = {
    Environment = "production"
    Purpose     = "sensitive-data-encryption"
  }
}

resource "aws_s3_bucket" "prod_data" {
  bucket = "company-prod-data"
  tags = {
    Environment     = "production"
    DataSensitivity = "customer-sensitive"
    Purpose         = "application-logs-and-backups"
    ManagedBy       = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "prod_data" {
  bucket = aws_s3_bucket.prod_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "prod_data" {
  bucket = aws_s3_bucket.prod_data.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "prod_data" {
  bucket                  = aws_s3_bucket.prod_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "prod_data" {
  bucket = aws_s3_bucket.prod_data.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.prod_data.arn,
          "${aws_s3_bucket.prod_data.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = false
          }
        }
      }
    ]
  })
}