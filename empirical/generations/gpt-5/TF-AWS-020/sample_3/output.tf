terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "region" {
  description = "AWS region for the provider (Organizations is a global service; region selection does not impact SCPs)."
  type        = string
  default     = "us-east-1"
}

variable "target_ou_id" {
  description = "The ID of the Organizational Unit to attach the SCP to (e.g., ou-abcd-12345678)."
  type        = string

  validation {
    condition     = can(regex("^ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}$", var.target_ou_id))
    error_message = "target_ou_id must be a valid OU ID (e.g., ou-abcd-12345678)."
  }
}

provider "aws" {
  region = var.region
}

resource "aws_organizations_policy" "deny_iam_user_creation" {
  name        = "Deny-IAM-User-Creation"
  description = "Service control policy to deny creation of IAM users; enforces role-only access model."
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyCreateIamUsers"
        Effect   = "Deny"
        Action   = [
          "iam:CreateUser"
        ]
        Resource = "*"
      }
    ]
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_policy_attachment" "attach_to_ou" {
  policy_id = aws_organizations_policy.deny_iam_user_creation.id
  target_id = var.target_ou_id
}