terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "oncall_email" {
  description = "Email address for the on-call distribution list to subscribe to critical alerts"
  type        = string
  validation {
    condition     = can(regex("^.+@.+\\..+$", var.oncall_email))
    error_message = "oncall_email must be a valid email address."
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

resource "aws_sns_topic" "critical_alerts" {
  name              = "critical-alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = "critical-alerts"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic_policy" "this" {
  arn    = aws_sns_topic.critical_alerts.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "DenyNonTLS",
        Effect    = "Deny",
        Principal = "*",
        Action    = "SNS:*",
        Resource  = aws_sns_topic.critical_alerts.arn,
        Condition = {
          Bool = {
            "aws:SecureTransport" = false
          }
        }
      },
      {
        Sid      = "AllowCloudWatchPublish",
        Effect   = "Allow",
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        },
        Action   = "SNS:Publish",
        Resource = aws_sns_topic.critical_alerts.arn,
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          },
          ArnLike = {
            "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alarm:*"
          }
        }
      },
      {
        Sid      = "AllowAccountPublish",
        Effect   = "Allow",
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "SNS:Publish",
        Resource = aws_sns_topic.critical_alerts.arn
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "oncall_email" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = var.oncall_email
}