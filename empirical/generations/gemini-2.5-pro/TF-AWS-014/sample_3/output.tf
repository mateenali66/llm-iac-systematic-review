resource "aws_cloudwatch_log_group" "prod_app_logs" {
  name              = "/aws/app/prod"
  retention_in_days = 30

  tags = {
    Name        = "prod-app-logs"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}