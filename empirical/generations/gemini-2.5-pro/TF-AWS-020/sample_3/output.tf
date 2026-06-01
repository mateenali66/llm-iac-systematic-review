variable "target_ou_name" {
  type        = string
  description = "The name of the Organizational Unit to which the SCP will be attached."
}

variable "target_ou_parent_id" {
  type        = string
  description = "The parent ID of the target Organizational Unit (can be the root ID or another OU ID)."
}

data "aws_organizations_organizational_unit" "target" {
  name      = var.target_ou_name
  parent_id = var.target_ou_parent_id
}

data "aws_iam_policy_document" "deny_iam_user_creation" {
  statement {
    sid    = "DenyIamUserCreation"
    effect = "Deny"
    actions = [
      "iam:CreateUser"
    ]
    resources = ["*"]
  }
}

resource "aws_organizations_policy" "deny_iam_user_creation" {
  name        = "Deny-IAM-User-Creation"
  description = "Denies the ability to create IAM users. IAM roles should be used instead."
  content     = data.aws_iam_policy_document.deny_iam_user_creation.json
}

resource "aws_organizations_policy_attachment" "deny_iam_user_creation_attachment" {
  policy_id = aws_organizations_policy.deny_iam_user_creation.id
  target_id = data.aws_organizations_organizational_unit.target.id
}