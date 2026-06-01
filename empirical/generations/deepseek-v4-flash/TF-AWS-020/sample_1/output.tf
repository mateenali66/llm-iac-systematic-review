resource "aws_organizations_policy" "deny_iam_user_creation" {
  name        = "DenyIAMUserCreation"
  description = "Denies creation of IAM users across all accounts in the OU; only roles are allowed."
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyIAMUserCreation"
        Effect   = "Deny"
        Action   = "iam:CreateUser"
        Resource = "*"
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "ou_attachment" {
  policy_id = aws_organizations_policy.deny_iam_user_creation.id
  target_id = var.organizational_unit_id
}

variable "organizational_unit_id" {
  description = "The ID of the organizational unit to attach the SCP to."
  type        = string
}