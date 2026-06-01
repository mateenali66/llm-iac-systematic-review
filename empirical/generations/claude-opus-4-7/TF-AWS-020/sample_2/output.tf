terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for provider configuration. Organizations is a global service, but a region is required."
  type        = string
  default     = "us-east-1"
}

variable "target_ou_id" {
  description = "The ID of the Organizational Unit to which the SCP will be attached (e.g., ou-abcd-12345678)."
  type        = string

  validation {
    condition     = can(regex("^ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}$", var.target_ou_id))
    error_message = "The target_ou_id must be a valid AWS Organizations OU ID (e.g., ou-abcd-12345678)."
  }
}

variable "policy_name" {
  description = "Name of the Service Control Policy."
  type        = string
  default     = "DenyIAMUserCreation"
}

variable "tags" {
  description = "Tags to apply to the SCP."
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Purpose   = "IAMGuardrail"
  }
}

data "aws_iam_policy_document" "deny_iam_user_creation" {
  statement {
    sid    = "DenyIAMUserCreation"
    effect = "Deny"

    actions = [
      "iam:CreateUser",
      "iam:CreateLoginProfile",
      "iam:CreateAccessKey",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "DenyIAMUserGroupAndPolicyAttachments"
    effect = "Deny"

    actions = [
      "iam:AddUserToGroup",
      "iam:AttachUserPolicy",
      "iam:PutUserPolicy",
      "iam:CreateGroup",
    ]

    resources = ["*"]
  }
}

resource "aws_organizations_policy" "deny_iam_user_creation" {
  name        = var.policy_name
  description = "Denies the creation of IAM users and related credentials across member accounts. Only IAM roles are permitted for identity management."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.deny_iam_user_creation.json

  tags = var.tags
}

resource "aws_organizations_policy_attachment" "deny_iam_user_creation" {
  policy_id = aws_organizations_policy.deny_iam_user_creation.id
  target_id = var.target_ou_id
}

output "policy_id" {
  description = "The ID of the created SCP."
  value       = aws_organizations_policy.deny_iam_user_creation.id
}

output "policy_arn" {
  description = "The ARN of the created SCP."
  value       = aws_organizations_policy.deny_iam_user_creation.arn
}

output "attached_ou_id" {
  description = "The OU ID to which the SCP is attached."
  value       = var.target_ou_id
}