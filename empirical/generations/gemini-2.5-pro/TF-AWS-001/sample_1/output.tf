provider "aws" {
  region = "us-east-1"
}

# --- S3 Bucket for Access Logs ---
# A separate, secure bucket to store access logs for the main data bucket.
resource "aws_s3_bucket" "log_bucket" {
  bucket = "company-prod-data-access-logs" # NOTE: S