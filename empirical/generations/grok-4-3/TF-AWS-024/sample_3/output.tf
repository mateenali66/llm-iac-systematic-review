resource "aws_sns_topic" "critical_alerts" {
  name              = "critical-alerts"
  display_name      = "Critical Alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Environment = "production"
    Purpose     = "incident-notifications"
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic_policy" "critical_alerts" {
  arn = aws_sns_topic.critical_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyUnencryptedPublish"
        Effect = "Deny"
        Principal = "*"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.critical_alerts.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}