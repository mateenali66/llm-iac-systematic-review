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
  description = "AWS region for the provider"
  type        = string
  default     = "us-east-1"
}

variable "target_ou_id" {
  description = "The ID of the Organizational Unit to attach the SCP to (e.g., ou-xxxx-xxxxxxxx)"
  type        = string

  validation {
    condition     = can(regex("^ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}$", var.target_ou_id))
    error_message = "The target_ou_id must be a valid AWS Organizations OU ID (e.g., ou-xxxx-xxxxxxxx)."
  }
}

variable "policy_name" {
  description = "Name of the Service Control Policy"
  type        = string
  default     = "DenyIAMUserCreation"
}

variable "policy_description" {
  description = "Description of the Service Control Policy"
  type        = string
  default     = "Denies the creation of IAM users across member accounts. Only IAM roles are permitted for identity management."
}

variable "tags" {
  description = "Tags to apply to the SCP"
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Purpose     = "Security-Guardrail"
    Compliance  = "IAM-Best-Practices"
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
    sid    = "DenyIAMUserGroupManagement"
    effect = "Deny"

    actions = [
      "iam:CreateGroup",
      "iam:AddUserToGroup",
      "iam:AttachUserPolicy",
      "iam:PutUserPolicy",
      "iam:UpdateUser",
    ]

    resources = ["*"]
  }
}

resource "aws_organizations_policy" "deny_iam_user_creation" {
  name        = var.policy_name
  description = var.policy_description
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.deny_iam_user_creation.json

  tags = var.tags
}

resource "aws_organizations_policy_attachment" "deny_iam_user_creation" {
  policy_id = aws_organizations_policy.deny_iam_user_creation.id
  target_id = var.target_ou_id
}

output "scp_id" {
  description = "The ID of the created Service Control Policy"
  value       = aws_organizations_policy.deny_iam_user_creation.id
}

output "scp_arn" {
  description = "The ARN of the created Service Control Policy"
  value       = aws_organizations_policy.deny_iam_user_creation.arn
}

output "scp_attached_target" {
  description = "The OU target to which the SCP is attached"
  value       = aws_organizations_policy_attachment.deny_iam_user_creation.target_id
}