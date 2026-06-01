terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "aws_region" {
  description = "AWS region for API calls (Organizations is global but a region must be specified)."
  type        = string
  default     = "us-east-1"
}

variable "target_ou_id" {
  description = "AWS Organizations OU ID to attach the SCP to, e.g., ou-abcd-12345678."
  type        = string

  validation {
    condition     = can(regex("^ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}$", var.target_ou_id))
    error_message = "target_ou_id must be a valid OU ID like ou-abcd-12345678."
  }
}

variable "policy_name" {
  description = "Name of the SCP."
  type        = string
  default     = "Deny-IAM-User-Creation"
}

variable "policy_description" {
  description = "Description of the SCP."
  type        = string
  default     = "Denies creation of IAM users across all accounts in the specified OU to enforce role-based access."
}

variable "tags" {
  description = "Tags to apply to the SCP."
  type        = map(string)
  default     = {}
}

provider "aws" {
  region = var.aws_region
}

resource "aws_organizations_policy" "deny_iam_user_creation" {
  name        = var.policy_name
  description = var.policy_description
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyIAMUserCreation"
        Effect   = "Deny"
        Action   = ["iam:CreateUser"]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    {
      ManagedBy = "Terraform"
      Purpose   = "SecurityGuardrail"
    },
    var.tags
  )
}

resource "aws_organizations_policy_attachment" "attach_to_ou" {
  policy_id = aws_organizations_policy.deny_iam_user_creation.id
  target_id = var.target_ou_id
}