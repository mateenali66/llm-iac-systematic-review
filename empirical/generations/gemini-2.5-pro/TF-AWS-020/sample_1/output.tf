terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_organizations_organization" "org" {}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_policy" "deny_iam_user_creation" {
  name        = "DenyIamUserCreation"
  description = "Denies the ability to create new IAM users. IAM roles should be used instead."

  content = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "DenyIamUserCreation",
        Effect   = "Deny",
        Action   = "iam:CreateUser",
        Resource = "*"
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "deny_iam_user_creation_attach" {
  policy_id = aws_organizations_policy.deny_iam_user_creation.id
  target_id = aws_organizations_organizational_unit.workloads.id
}