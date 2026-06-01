provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "marketing_website" {
  bucket = "www.example.com"
}

resource "aws_s3_bucket_public_access_block" "marketing_website" {
  bucket = aws_s3_bucket.marketing_website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "marketing_website" {
  bucket = aws_s3_bucket.marketing_website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.marketing_website.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.marketing_website]
}

resource "aws_s3_bucket_website_configuration" "marketing_website" {
  bucket = aws_s3_bucket.marketing_website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_versioning" "marketing_website" {
  bucket = aws_s3_bucket.marketing_website.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "marketing_website" {
  bucket = aws_s3_bucket.marketing_website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}