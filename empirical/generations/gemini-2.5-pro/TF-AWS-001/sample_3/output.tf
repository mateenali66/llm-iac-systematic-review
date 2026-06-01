data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "access_logs" {
  bucket = "company-prod-data-access-logs"

  tags = {
    Name        = "S3 Access Log Bucket for company-prod-data"
    Environment = "production"
    ManagedBy   = "Terra