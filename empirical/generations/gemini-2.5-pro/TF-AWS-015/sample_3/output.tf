terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "application_iam_role_arn" {
  description = "The ARN of the IAM role for the application that needs to use this KMS key."
  type        = string
}

variable "environment" {
  description = "The deployment environment name (e.g., 'prod', 'staging')."
  type        = string
  default     = "prod"
}

variable "application_name" {
  description = "The name of the application this key is for."
  type        = string
  default     = "customer-pii-service"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "pii_data_key_policy" {
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowApplicationRoleToUseKey"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [var.application_iam_role_arn]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "pii_data" {
  description             = "KMS key for encrypting customer PII data in S3"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.pii_data_key_policy.json
  tags = {
    Name        = "${var.application_name}-pii-key"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_alias" "pii_data" {
  name          = "alias/${var.application_name}-pii-key"
  target_key_id = aws_kms_key.pii_data.key_id
}