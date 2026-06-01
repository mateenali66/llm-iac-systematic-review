variable "ou_name" {
  description = "The name of the Organizational Unit to attach the SCP to."
  type        = string
  default     = "Workloads"
}

variable "policy_name" {
  description = "The friendly name for the Service Control Policy."
  type        = string
  default     = "DenyIamUserCreation"
}

variable "policy_description" {
  description = "The description for the Service Control Policy."
  type        = string
  default     = "Denies the creation of IAM users, enforcing the use of IAM roles for federated access."
}

data "aws_organizations_organization" "org" {}

data "aws_organizations_organizational_units" "target" {
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

locals {
  target_ou_id = [for ou in data.aws_organizations_organizational_units.target.children : ou.id if ou.name == var.ou_name][0]
}

resource "aws_organizations_policy" "deny_iam_user_creation" {
  name        = var.policy_name
  description = var.policy_description
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyIamUserCreation"
        Effect   = "Deny"
        Action   = "iam:CreateUser"
        Resource = "*"
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "deny_iam_user_creation_attachment" {
  policy_id = aws_organizations_policy.deny_iam_user_creation.id
  target_id = local.target_ou_id
}