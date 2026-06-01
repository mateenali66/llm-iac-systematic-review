provider "aws" {
  region = "us-west-2"
}

resource "aws_sns_topic" "critical_alerts" {
  name = "critical-alerts"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = "oncall-email-distribution-list@example.com"
}

resource "aws_iam_policy" "sns_publish_policy" {
  name        = "sns-publish-policy"
  description = "Policy to allow publishing to SNS topic"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sns:Publish"
        Resource = aws_sns_topic.critical_alerts.arn
      }
    ]
  })
}

resource "aws_iam_role" "sns_publish_role" {
  name        = "sns-publish-role"
  description = "Role to allow publishing to SNS topic"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sns_publish_policy_attachment" {
  role       = aws_iam_role.sns_publish_role.name
  policy_arn = aws_iam_policy.sns_publish_policy.arn
}