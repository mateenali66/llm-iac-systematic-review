data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_elb_service_account" "main" {}

resource "random_pet" "bucket_name" {
  length = 2
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = "