resource "aws_organizations_policy" "deny_iam_user_creation" {
  name        = "DenyIAMUserCreation"
  description = "Denies creation of IAM users across all accounts in the OU. Only roles are allowed."
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyIAMUserCreation"
        Effect   = "Deny"
        Action   = [
          "iam:CreateUser",
          "iam:CreateLoginProfile",
          "iam:CreateAccessKey",
          "iam:CreateServiceSpecificCredential",
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:ResyncMFADevice",
          "iam:DeactivateMFADevice",
          "iam:DeleteVirtualMFADevice",
          "iam:UpdateLoginProfile",
          "iam:UpdateAccessKey",
          "iam:UpdateServiceSpecificCredential",
          "iam:UploadSigningCertificate",
          "iam:UpdateSigningCertificate",
          "iam:DeleteSigningCertificate",
          "iam:UploadServerCertificate",
          "iam:UpdateServerCertificate",
          "iam:DeleteServerCertificate",
          "iam:UploadSSHPublicKey",
          "iam:UpdateSSHPublicKey",
          "iam:DeleteSSHPublicKey"
        ]
        Resource = "*"
        Condition = {
          StringNotLikeIfExists = {
            "iam:ResourceTag/aws:createdBy" = "AWSOrganizations"
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "deny_iam_user_attachment" {
  policy_id = aws_organizations_policy.deny_iam_user_creation.id
  target_id = var.target_ou_id
}

variable "target_ou_id" {
  description = "The ID of the organizational unit to attach the SCP to"
  type        = string
}