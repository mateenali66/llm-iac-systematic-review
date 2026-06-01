resource "aws_organizations_policy" "deny_iam_user_creation" {
  name        = "DenyIAMUserCreation"
  description = "Denies IAM user creation in all accounts; IAM roles only"
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyCreateUser"
      Effect   = "Deny"
      Action   = "iam:CreateUser"
      Resource = "*"
    }]
  })
}