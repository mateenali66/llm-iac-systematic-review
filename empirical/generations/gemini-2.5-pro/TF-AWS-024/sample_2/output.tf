variable "on_call_email" {
  description = "The email address for the on-call distribution list to receive critical alerts."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default = {
    "Environment" = "production"
    "ManagedBy"   = "Terraform"
    "Project"     = "IncidentResponse"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "sns_topic_key" {
  description             = "KMS key for encrypting the critical-alerts SNS topic"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "sns_topic_key_alias" {
  name          = "alias/sns/critical-alerts"
  target_key_id = aws_kms_key.sns_topic_key.key_id
}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "critical-alerts-sns-policy"

  statement {
    sid    = "AllowAccountOwner"
    effect = "Allow"
    actions = [
      "SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
      "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic",
      "SNS:Publish"
    ]
    resources = [
      "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:critical-alerts"
    ]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid    = "AllowMonitoringServices"
    effect = "Allow"
    actions = [
      "SNS:Publish"
    ]
    resources = [
      "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:critical-alerts"
    ]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "cloudwatch.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic" "critical_alerts" {
  name              = "critical-alerts"
  kms_master_key_id = aws_kms_key.sns_topic_key.arn
  policy            = data.aws_iam_policy_document.sns_topic_policy.json
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "on_call_email_subscription" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = var.on_call_email
}

output "sns_topic_arn" {
  description = "The ARN of the critical-alerts SNS topic."
  value       = aws_sns_topic.critical_alerts.arn
}