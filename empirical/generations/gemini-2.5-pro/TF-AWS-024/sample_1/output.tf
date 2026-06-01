variable "on_call_email" {
  description = "The on-call email distribution list for critical alerts."
  type        = string
  nullable    = false
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "sns_topic_key" {
  description             = "KMS key for encrypting the critical-alerts SNS topic"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name      = "critical-alerts-sns-key"
    Purpose   = "SNS Topic Encryption"
    ManagedBy = "Terraform"
  }
}

resource "aws_kms_alias" "sns_topic_key" {