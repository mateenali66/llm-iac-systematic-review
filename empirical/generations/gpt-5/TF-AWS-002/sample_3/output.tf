resource "aws_s3_bucket" "website" {
  bucket        = "www.example.com"
  force_destroy = false

  tags = {
    Name        = "www.example.com-website"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls   = true
  ignore_public_acls  = true
  block_public_policy = false
  restrict_public_buckets = false
}

data "aws_iam_policy_document" "website_public_read" {
  statement {
    sid = "AllowPublicReadGetObject"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.website.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "website_public_read" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website_public_read.json

  depends_on = [aws_s3_bucket_public_access_block.website]
}

resource "aws_s3_bucket_lifecycle_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "abort-incomplete-mpu"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}