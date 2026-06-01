terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "application_role_arn" {
  type        = string
  description = "ARN of the application's IAM role allowed to use the KMS key."
}

variable "s3_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket (e.g., arn:aws:s3:::my-pii-bucket) whose objects will be encrypted with this key."
}

variable "kms_alias" {
  type        = string
  description = "KMS alias for the key."
  default     = "alias/pii-s3"
  validation {
    condition     = can(regex("^alias\\/[A-Za-z0-9/_-]{1,256}$", var.kms_alias))
    error_message = "kms_alias must start with 'alias/' and contain only letters, numbers, '/', '_', or '-'."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the KMS key."
  default     = {}
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  account_root_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
}

resource "aws_kms_key" "pii_s3" {
  description             = "KMS key for encrypting customer PII stored in S3. Usage restricted to the application IAM role via S3 only."
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAdminPermissions"
        Effect    = "Allow"
        Principal = { AWS = local.account_root_arn }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowAppRoleS3UseOnly"
        Effect    = "Allow"
        Principal = { AWS = var.application_role_arn }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ListGrants"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${data.aws_region.current.name}.${data.aws_partition.current.dns_suffix}"
          }
          Bool = {
            "kms:GrantIsForAWSResource" = true
          }
          StringLike = {
            "kms:EncryptionContext:aws:s3:arn" = "${var.s3_bucket_arn}/*"
          }
        }
      }
    ]
  })
  tags = merge(
    {
      Name      = "pii-s3-kms"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

resource "aws_kms_alias" "pii_s3" {
  name          = var.kms_alias
  target_key_id = aws_kms_key.pii_s3.key_id
}

output "kms_key_arn" {
  value = aws_kms_key.pii_s3.arn
}

output "kms_key_id" {
  value = aws_kms_key.pii_s3.key_id
}

output "kms_alias_arn" {
  value = aws_kms_alias.pii_s3.arn
}