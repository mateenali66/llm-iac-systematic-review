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

        text_transformations {
          type = "URL_DECODE"
        }

        text_transformations {
          type = "HTML_ENTITY_DECODE"
        }

        sensitivity_level = "LOW"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "sql-injection-rule-metric"
      sampled_requests_enabled   = true
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

        text_transformations {
          type = "URL_DECODE"
        }

        text_transformations {
          type = "HTML_ENTITY_DECODE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "xss-rule-metric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "sql-injection-xss-web-acl-metric"
    sampled_requests_enabled   = true
  }
}

resource "aws_cloudfront_distribution" "example" {
  origin {
    domain_name = "example.com"
    origin_id   = "example-origin"
  }

  enabled = true

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

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  web_acl_id = aws_wafv2_web_acl.sql_injection_xss.arn
}

output "web_acl_arn" {
  value = aws_wafv2_web_acl.sql_injection_xss.arn
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.example.id
}