provider "aws" {
  region = "us-west-2"
}

resource "aws_kms_key" "customer_pii_key" {
  description             = "KMS key for encrypting customer PII in S3"
  deletion_window_in_days = 10
}

resource "aws_kms_alias" "customer_pii_key_alias" {
  name          = "alias/customer-pii-key"
  target_key_id = aws_kms_key.customer_pii_key.key_id
}

resource "aws_iam_role" "application_role" {
  name        = "application-role"
  description = "IAM role for the application"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "kms_key_policy" {
  name        = "kms-key-policy"
  description = "Policy for accessing the KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowApplicationRoleToUseKey"
        Effect    = "Allow"
        Action    = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.customer_pii_key.arn
        Principal = {
          AWS = aws_iam_role.application_role.arn
        }
      },
      {
        Sid       = "AllowKeyAdministration"
        Effect    = "Allow"
        Action    = [
          "kms:Create*",
          "kms:List*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:Disable*",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ]
        Resource = aws_kms_key.customer_pii_key.arn
        Principal = {
          AWS = "arn:aws:iam::123456789012:root"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "kms_key_policy_attachment" {
  role       = aws_iam_role.application_role.name
  policy_arn = aws_iam_policy.kms_key_policy.arn
}