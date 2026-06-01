resource "aws_s3_bucket" "prod_data" {
  bucket = "company-prod-data"

  # Prevent accidental deletion of production data
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "company-prod-data"
    Environment = "production"
    Purpose     = "application-logs-and-config-backups"
  }
}

# Block all public access to the bucket
resource "aws_s3_bucket_public_access_block" "prod_data" {
  bucket = aws_s3_bucket.prod_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable server-side encryption with AES256
resource "aws_s3_bucket_server_side_encryption_configuration" "prod_data" {
  bucket = aws_s3_bucket.prod_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable versioning to protect against accidental deletion/overwrites
resource "aws_s3_bucket_versioning" "prod_data" {
  bucket = aws_s3_bucket.prod_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Deny insecure (HTTP) requests
resource "aws_s3_bucket_policy" "prod_data" {
  bucket = aws_s3_bucket.prod_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.prod_data.arn,
          "${aws_s3_bucket.prod_data.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
    ]
  })
}