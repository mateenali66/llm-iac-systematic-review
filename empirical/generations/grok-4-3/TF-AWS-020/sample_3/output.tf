resource "aws_organizations_policy" "deny_iam_user_creation" {
  name        = "DenyIAMUserCreation"
  description = "Denies IAM user creation in all accounts; IAM roles are permitted"
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

variable "target_organizational_unit_id" {
  description = "Root or OU ID to attach the SCP"
  type        = string
}

resource "aws_organizations_policy_attachment" "deny_iam_user_creation" {
  policy_id = aws_organizations_policy.deny_iam_user_creation.id
  target_id = var.target_organizational_unit_id
}