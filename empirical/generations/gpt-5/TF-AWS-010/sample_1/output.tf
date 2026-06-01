terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Environment tag"
  default     = "prod"
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags to merge into all resources"
  default     = {}
}

locals {
  tags = merge({
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.extra_tags)
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

resource "aws_kms_key" "dynamodb_user_sessions" {
  description         = "CMK for DynamoDB table user-sessions"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "EnableIAMUserPermissions",
        Effect   = "Allow",
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid      = "AllowDynamoDBUseOfTheKey",
        Effect   = "Allow",
        Principal = {
          Service = "dynamodb.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ListGrants"
        ],
        Resource  = "*",
        Condition = {
          StringEquals = {
            "kms:ViaService"                                   = "dynamodb.${var.aws_region}.amazonaws.com",
            "kms:EncryptionContext:aws:dynamodb:tableName"     = "user-sessions"
          },
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "dynamodb-user-sessions-kms"
  })
}

resource "aws_kms_alias" "dynamodb_user_sessions" {
  name          = "alias/dynamodb/user-sessions"
  target_key_id = aws_kms_key.dynamodb_user_sessions.key_id
}

resource "aws_dynamodb_table" "user_sessions" {
  name                        = "user-sessions"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "session_id"
  deletion_protection_enabled = true

  attribute {
    name = "session_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_user_sessions.arn
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = merge(local.tags, {
    Name        = "user-sessions"
    Application = "sessions"
    Service     = "dynamodb"
  })
}