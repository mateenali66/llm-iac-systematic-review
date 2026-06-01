provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "marketing_website" {
  bucket = "www.example.com"
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  tags = {
    Name        = "Marketing Website"
    Environment = "production"
  }
}

resource "aws_s3_bucket_policy" "marketing_website_policy" {
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
}

output "website_endpoint" {
  value = aws_s3_bucket.marketing_website.website_endpoint
}

output "bucket_domain_name" {
  value = aws_s3_bucket.marketing_website.bucket_domain_name
}