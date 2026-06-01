resource "aws_organizations_policy" "deny_iam_users" {
  name        = "DenyIAMUsers"
  description = "Denies creation of IAM users - only roles allowed"
  content     = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyIAMUserCreation"
        Effect    = "Deny"
        Action    = [
          "iam:CreateUser",
          "iam:CreateAccessKey"
        ]
        Resource  = "*"
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "deny_iam_users_attachment" {
  policy_id = aws_organizations_policy.deny_iam_users.id
  target_id = var.organizational_unit_id
}