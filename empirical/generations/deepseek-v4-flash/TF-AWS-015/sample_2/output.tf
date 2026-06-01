resource "aws_kms_key" "pii_encryption_key" {
  description             = "KMS key for encrypting customer PII in S3"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  is_enabled              = true
  key_usage               = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Application Role to Use Key"
        Effect = "Allow"
        Principal = {
          AWS = var.application_role_arn
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
  tags = {
    Name        = "pii-encryption-key"
    Environment = var.environment
    Purpose     = "PII Encryption"
  }
}

resource "aws_kms_alias" "pii_encryption_key_alias" {
  name          = "alias/${var.environment}-pii-encryption-key"
  target_key_id = aws_kms_key.pii_encryption_key.key_id
}

data "aws_caller_identity" "current" {}

variable "application_role_arn" {
  description = "ARN of the IAM role that the application uses"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}