variable "app_iam_role_arn" {
  description = "ARN of the IAM role permitted to use the KMS key"
  type        = string
}

resource "aws_kms_key" "pii" {
  description             = "Customer PII encryption key for S3"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "pii-key-policy"
    Statement = [
      {
        Sid    = "AllowRootAdmin"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowAppRoleUsage"
        Effect = "Allow"
        Principal = {
          AWS = var.app_iam_role_arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "pii" {
  name          = "alias/pii-s3"
  target_key_id = aws_kms_key.pii.key_id
}

data "aws_caller_identity" "current" {}