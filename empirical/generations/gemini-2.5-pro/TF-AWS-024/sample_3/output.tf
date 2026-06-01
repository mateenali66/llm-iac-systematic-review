variable "on_call_email_distribution_list" {
  description = "The email address for the on-call distribution list to receive critical alerts."
  type        = string
  validation {
    condition     = can(regex("@", var.on_call_email_distribution_list))
    error_message = "The on_call_email_distribution_list must be a valid email address."
  }
}

locals {
  name = "critical-alerts"
  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
    Project     = "incident-management"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "critical_alerts" {
  name              = local.name
  kms_master_key_id = "alias/aws/sns"
  tags              =