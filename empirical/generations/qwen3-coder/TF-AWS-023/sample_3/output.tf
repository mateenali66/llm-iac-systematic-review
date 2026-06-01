resource "aws_cloudfront_distribution" "example" {
  origin {
    domain_name = "example.com"
    origin_id   = "myS3Origin"

    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/EXAMPLE"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Example CloudFront distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "myS3Origin"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_wafv2_web_acl" "example" {
  name        = "example-web-acl"
  description = "Web ACL for blocking SQL injection and XSS attacks"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "SQLInjectionRule"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLInjectionRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "XSSRule"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        excluded_rule {
          name = "SizeRestrictions_QUERYSTRING"
        }

        excluded_rule {
          name = "NoUserAgent_HEADER"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "XSSRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "example-web-acl-metric"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "example-web-acl"
  }
}

resource "aws_wafv2_web_acl_association" "example" {
  resource_arn = aws_cloudfront_distribution.example.arn
  web_acl_arn  = aws_wafv2_web_acl.example.arn
}