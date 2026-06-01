resource "aws_sns_topic" "critical_alerts" {
  name         = "critical-alerts"
  display_name = "Production Critical Alerts"

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
        Sid    = "AllowPublishFromOwnAccount"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.critical_alerts.arn
        Condition = {
          StringEquals = {
            "AWS:SourceOwner" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = "oncall@example.com"

  depends_on = [aws_sns_topic_policy.critical_alerts_policy]
}