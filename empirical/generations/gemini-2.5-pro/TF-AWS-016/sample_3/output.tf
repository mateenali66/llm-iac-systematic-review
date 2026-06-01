data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "random_password" "db_password" {
  length           = 32
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1