resource "aws_cloudwatch_log_group" "/aws/app/prod" {
  name              = "/aws/app/prod"
  retention_in_days = 30

  tags = {
    Environment = "production"
    Application = "app"
  }
}