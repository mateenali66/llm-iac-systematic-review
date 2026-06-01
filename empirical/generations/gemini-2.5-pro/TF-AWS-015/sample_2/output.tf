variable "application_iam_role_arn" {
  type        = string
  description = "The ARN of the IAM role for the application that will use this KMS key."
  nullable    = false
}

variable "app_name" {
  type        = string
  description = "The name of the application, used for tagging and alias creation."
  default     = "customer-app"
}

variable "environment" {
  type        = string
  description = "The deployment environment, used for tagging and alias creation."
  default     = "production"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "pii_key_policy" {
  # tfsec:ignore:aws-iam-no-policy-wildcards - The root principal needs full control to prevent lockout.
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
    sid    = "AllowApplicationRoleToUseTheKey"
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

  statement {
    sid    = "AllowApplicationRoleToCreateGrants"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [var.application_iam_role_arn]
    }
    actions = [
      "kms:CreateGrant",
      "kms:List