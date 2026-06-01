data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "random_pet" "bucket_suffix" {
  length = 2
}

locals {
  bucket_name = "log-delivery-${data.aws_caller_identity.current.account_id}-${data.aws_region