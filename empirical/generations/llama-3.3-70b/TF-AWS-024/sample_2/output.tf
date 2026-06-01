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

output "sns_topic_arn" {
  value = aws_sns_topic.critical_alerts.arn
}