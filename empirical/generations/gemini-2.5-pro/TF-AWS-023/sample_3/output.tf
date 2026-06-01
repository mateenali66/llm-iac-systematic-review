variable "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution to associate the WAF ACL with."
  type        = string
}

resource "aws_wafv2_web_acl" "main" {
  name        = "cloudfront-web-acl"
  description = "WAFv2 ACL for CloudFront to block common web attacks."
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-Managed-SQLi-Rule"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-managed-sqli-rule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-Managed-XSS-Rule"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
        # This common rule set includes XSS, security misconfigurations, etc.
        # We can exclude specific rules if they cause false positives.
        # Example:
        # excluded_rule {
        #   name = "CrossSiteScripting_BODY"
        # }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-managed-xss-rule"