resource "aws_sns_topic" "critical_alerts" {
  name              = "critical-alerts"
  display_name      = "Production Critical Alerts"
  kms_master_key_id = "alias/aws/sns"
  
  tags = {
    Environment = "production"
    Purpose     = "incident-notifications"
  }
}

resource "aws_sns_topic_policy" "critical_alerts" {
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
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.critical_alerts.arn
        Condition = {
          StringEquals = {
            "AWS:SourceOwner" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowSubscribeFromOwnAccount"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "SNS:Subscribe"
        ]
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

output "sns_topic_arn" {
  value = aws_sns_topic.critical_alerts.arn
}