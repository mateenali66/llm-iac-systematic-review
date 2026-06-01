variable "oncall_email" {
  description = "Email address of the on-call distribution list"
  type        = string
  sensitive   = true
}

resource "aws_sns_topic" "critical_alerts" {
  name              = "critical-alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Environment = "production"
    Purpose     = "incident-notifications"
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = var.oncall_email
}