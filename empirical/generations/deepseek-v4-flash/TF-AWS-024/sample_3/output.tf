resource "aws_sns_topic" "critical_alerts" {
  name = "critical-alerts"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = var.on_call_email
}

variable "on_call_email" {
  description = "Email address for the on-call distribution list"
  type        = string
}