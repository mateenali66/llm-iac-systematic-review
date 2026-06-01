provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_wafv2_web_acl" "main" {
  provider = aws.us_east_1

  name        = "cloudfront-protection-acl"
  description = "Blocks common SQLi and