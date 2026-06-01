resource "aws_organizations_policy" "deny_iam_user_creation" {
  name        = "DenyIAMUserCreation"
  description = "Denies creation of IAM users across all accounts in the OU. Only roles are allowed."
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyIAMUserCreation"
        Effect   = "Deny"
        Action   = "iam:CreateUser"
        Resource = "*"
      },
      {
        Sid      = "DenyIAMUserModification"
        Effect   = "Deny"
        Action   = [
          "iam:UpdateUser",
          "iam:DeleteUser",
          "iam:CreateLoginProfile",
          "iam:UpdateLoginProfile",
          "iam:DeleteLoginProfile",
          "iam:ChangePassword",
          "iam:CreateAccessKey",
          "iam:UpdateAccessKey",
          "iam:DeleteAccessKey",
          "iam:CreateServiceSpecificCredential",
          "iam:UpdateServiceSpecificCredential",
          "iam:DeleteServiceSpecificCredential",
          "iam:UploadSigningCertificate",
          "iam:UpdateSigningCertificate",
          "iam:DeleteSigningCertificate",
          "iam:UploadSSHPublicKey",
          "iam:UpdateSSHPublicKey",
          "iam:DeleteSSHPublicKey",
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "iam:PutUserPolicy",
          "iam:DeleteUserPolicy",
          "iam:AddUserToGroup",
          "iam:RemoveUserFromGroup",
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:ResyncMFADevice",
          "iam:DeactivateMFADevice",
          "iam:DeleteVirtualMFADevice"
        ]
        Resource = "arn:aws:iam::*:user/*"
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "attach_to_ou" {
  policy_id = aws_organizations_policy.deny_iam_user_creation.id
  target_id = var.organizational_unit_id
}

variable "organizational_unit_id" {
  description = "The ID of the organizational unit to attach the SCP to."
  type        = string
}