resource "aws_cloudwatch_log_group" "prod_app" {
  name              = "/aws/app/prod"
  retention_in_days = 30

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}