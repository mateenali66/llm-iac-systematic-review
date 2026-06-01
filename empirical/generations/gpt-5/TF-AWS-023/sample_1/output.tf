provider "aws" {
  region = "us-east-1"
}

variable "origin_bucket_name" {
  description = "Name of the S3 bucket to serve as CloudFront origin"
  type        = string
}

variable "domain_name" {
  description = "CNAME for the CloudFront distribution"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for the CloudFront distribution"
  type        = string
}

data "aws_caller_identity" "current" {}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_s3_bucket" "origin" {
  bucket        = var.origin_bucket_name
  force_destroy = false

  tags = {
    Name = "cf-origin"
  }
}

resource "aws_s3_bucket_versioning" "origin" {
  bucket = aws_s3_bucket.origin.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "origin" {
  bucket = aws_s3_bucket.origin.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "origin" {
  bucket = aws_s3_bucket.origin.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "origin" {
  bucket                  = aws_s3_bucket.origin.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "cf-oac-${aws_s3_bucket.origin.id}"
  description                       = "OAC for S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_wafv2_web_acl" "cf" {
  name        = "cf-web-acl"
  description = "WAF for CloudFront blocking SQLi and XSS"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 1

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      sampled_requests_enabled  = true
      cloudwatch_metrics_enabled = true
      metric_name               = "SQLiRuleSet"
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesXSSRuleSet"
    priority = 2

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesXSSRuleSet"
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      sampled_requests_enabled  = true
      cloudwatch_metrics_enabled = true
      metric_name               = "XSSRuleSet"
    }
  }

  visibility_config {
    sampled_requests_enabled  = true
    cloudwatch_metrics_enabled = true
    metric_name               = "CFWebACL"
  }

  tags = {
    Name = "cf-web-acl"
  }
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution with WAFv2 (SQLi/XSS protection)"
  default_root_object = "index.html"
  web_acl_id          = aws_wafv2_web_acl.cf.arn
  aliases             = [var.domain_name]

  origin {
    domain_name = aws_s3_bucket.origin.bucket_regional_domain_name
    origin_id   = "s3-origin-${aws_s3_bucket.origin.id}"

    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id

    s3_origin_config {
      origin_access_identity = ""
    }
  }

  default_cache_behavior {
    target_origin_id       = "s3-origin-${aws_s3_bucket.origin.id}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  price_class = "PriceClass_100"

  tags = {
    Name = "cf-with-waf"
  }
}

resource "aws_s3_bucket_policy" "origin_allow_cf" {
  bucket = aws_s3_bucket.origin.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowCloudFrontReadViaOAC",
        Effect = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action   = ["s3:GetObject"],
        Resource = ["${aws_s3_bucket.origin.arn}/*"],
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.this.arn
          }
        }
      }
    ]
  })
}