provider "aws" {
  region = "us-west-2"
}

resource "aws_wafv2_web_acl" "sql_injection_xss" {
  name        = "sql-injection-xss-web-acl"
  description = "Web ACL to block common SQL injection and cross-site scripting attacks"
  scope       = "CLOUDFRONT"

  rule {
    name     = "sql-injection-rule"
    priority = 1

    action {
      block {}
    }

    statement {
      sql_injection_match_statement {
        field_to_match {
          uri_path {}
        }

        text_transformation {
          priority = 1
          type     = "URL_DECODE"
        }

        text_transformation {
          priority = 2
          type     = "HTML_ENTITY_DECODE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name               = "sql-injection-rule"
      sampled_requests_enabled  = true
    }
  }

  rule {
    name     = "xss-rule"
    priority = 2

    action {
      block {}
    }

    statement {
      xss_match_statement {
        field_to_match {
          query_string {}
        }

        text_transformation {
          priority = 1
          type     = "URL_DECODE"
        }

        text_transformation {
          priority = 2
          type     = "HTML_ENTITY_DECODE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name               = "xss-rule"
      sampled_requests_enabled  = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name               = "sql-injection-xss-web-acl"
    sampled_requests_enabled  = true
  }
}

resource "aws_cloudfront_distribution" "example" {
  enabled = true

  default_root_object = "index.html"

  aliases = ["example.com", "www.example.com"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "example-origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  origin {
    domain_name = "example.com"
    origin_id   = "example-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = "arn:aws:acm:us-west-2:123456789012:certificate/12345678-1234-1234-1234-123456789012"
    ssl_support_method  = "sni-only"
  }

  web_acl_id = aws_wafv2_web_acl.sql_injection_xss.arn
}