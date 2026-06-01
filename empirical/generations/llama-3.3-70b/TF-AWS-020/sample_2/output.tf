provider "aws" {
  region = "us-west-2"
}

resource "aws_organizations_policy" "deny_iam_users" {
  name        = "DenyIAMUsers"
  description = "Deny creation of IAM users across all member accounts"
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyIAMUsers"
        Effect    = "Deny"
        Action    = "iam:CreateUser"
        Resource = "*"
      },
    ]
  })
}

resource "aws_organizations_policy_attachment" "deny_iam_users_attachment" {
  policy_id = aws_organizations_policy.deny_iam_users.id
  target_id = aws_organizations_organizational_unit.example.id
}

resource "aws_organizations_organizational_unit" "example" {
  name      = "example-ou"
  parent_id = aws_organizations_organization.example.id
}

resource "aws_organizations_organization" "example" {
  aws_service_access_principals = [
    "organizations.amazonaws.com",
  ]
  feature_set = "ALL"
}