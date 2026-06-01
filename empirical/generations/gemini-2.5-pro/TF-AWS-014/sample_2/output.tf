resource "aws_cloudwatch_log_group" "app_prod" {
  name              = "/aws/app/prod"
  retention_in_days = 30

  tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}