provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "origin" {
  bucket = "my-static-website"
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

resource "aws_s3_bucket_policy" "origin_policy" {
  bucket = aws_s3_bucket.origin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = "${aws_s3_bucket.origin.arn}/*"
        Condition = {
          StringLike = {
            "aws:SourceIp" = "0.0.0.0/0"
          }
        }
      },
    ]
  })
}

resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name = aws_s3_bucket.origin.bucket_regional_domain_name
    origin_id   = "my-s3-origin"

    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/ABCDEFG123"
    }
  }

  enabled             = true
  is_ipv6_enabled      = true
  default_root_object = "index.html"

  aliases = ["my-static-website.com", "www.my-static-website.com"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "my-s3-origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.certificate.arn
    ssl_support_method  = "sni-only"
  }
}

resource "aws_acm_certificate" "certificate" {
  domain_name       = "my-static-website.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "certificate_validation" {
  certificate_arn = aws_acm_certificate.certificate.arn
  validation_record {
    name    = aws_route53_record.validation.name
    type    = aws_route53_record.validation.type
    value   = aws_route53_record.validation.value
  }
}

resource "aws_route53_record" "validation" {
  name    = aws_acm_certificate.certificate.domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.certificate.domain_validation_options[0].resource_record_type
  zone_id = aws_route53_zone.zone.id
  records = [aws_acm_certificate.certificate.domain_validation_options[0].resource_record_value]
  ttl     = 60
}

resource "aws_route53_zone" "zone" {
  name = "my-static-website.com"
}

resource "aws_route53_record" "alias" {
  name    = aws_route53_zone.zone.name
  type    = "A"
  zone_id = aws_route53_zone.zone.id

  alias {
    name                   = aws_cloudfront_distribution.distribution.domain_name
    zone_id                = aws_cloudfront_distribution.distribution.zone_id
    evaluate_target_health = false
  }
}