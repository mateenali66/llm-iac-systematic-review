resource "aws_sns_topic" "critical_alerts" {
  name              = "critical-alerts"
  display_name      = "Production Critical Alerts"
  kms_master_key_id = "alias/aws/sns"
  
  tags = {
    Environment = "production"
    Purpose     = "incident-notifications"
  }
}

resource "aws_sns_topic_policy" "critical_alerts_policy" {
  arn = aws_sns_topic.critical_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPublishFromCloudWatch"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.critical_alerts.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:cloudwatch:*"
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = "oncall@example.com"
}