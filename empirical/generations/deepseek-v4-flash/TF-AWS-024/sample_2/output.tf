resource "aws_sns_topic" "critical_alerts" {
  name = "critical-alerts"

  display_name = "Critical Alerts"

  # Enable server-side encryption for production security
  kms_master_key_id = "alias/aws/sns"

  # Prevent accidental deletion in production
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Environment = "production"
    Purpose     = "incident-notifications"
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = var.on_call_email_list

  # Ensure delivery retry policy for production reliability
  delivery_policy = jsonencode({
    healthyRetryPolicy = {
      minDelayTarget    = 20
      maxDelayTarget    = 20
      numRetries        = 3
      numNoDelayRetries = 0
      numMinDelayRetries  = 0
      numMaxDelayRetries  = 0
      backoffFunction    = "linear"
    }
  })
}

variable "on_call_email_list" {
  description = "Email distribution list for on-call incident notifications"
  type        = string
  sensitive   = true
}