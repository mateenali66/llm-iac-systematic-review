variable "app_iam_role_arn" {
  description = "ARN of the application IAM role permitted to use the KMS key"
  type        = string
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "pii" {
  description             = "Customer PII encryption key for S3"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "pii-key-policy"
    Statement = [
      {
        Sid    = "AllowAccountRoot"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowAppRole"
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
  name          = "alias/customer-pii"
  target_key_id = aws_kms_key.pii.key_id
}