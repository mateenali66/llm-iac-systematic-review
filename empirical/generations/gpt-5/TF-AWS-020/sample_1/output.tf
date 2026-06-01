terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "target_ou_id" {
  description = "The ID of the organizational unit (OU) to attach the SCP to, e.g., ou-xxxx-xxxxxxxx"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the SCP"
  type        = map(string)
  default     = {}
}

resource "aws_organizations_policy" "deny_iam_user_creation" {
  name        = "deny-iam-user-creation"
  description = "Deny creation of IAM users across accounts in the target OU; only roles are allowed."
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

  tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_policy_attachment" "attach_to_ou" {
  policy_id = aws_organizations_policy.deny_iam_user_creation.id
  target_id = var.target_ou_id

  lifecycle {
    prevent_destroy = true
  }
}