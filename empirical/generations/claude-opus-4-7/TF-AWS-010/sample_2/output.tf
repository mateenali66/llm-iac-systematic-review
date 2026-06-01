terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_kms_key" "dynamodb" {
  description             = "KMS key for encrypting the user-sessions DynamoDB table"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = {
    Name        = "user-sessions-dynamodb-kms"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "dynamodb" {
  name          = "alias/user-sessions-dynamodb"
  target_key_id = aws_kms_key.dynamodb.key_id
}

resource "aws_dynamodb_table" "user_sessions" {
  name         = "user-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  deletion_protection_enabled = true

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "user-sessions"
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "application-session-storage"
  }
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

output "table_name" {
  description = "The name of the DynamoDB table"
  value       = aws_dynamodb_table.user_sessions.name
}

output "table_arn" {
  description = "The ARN of the DynamoDB table"
  value       = aws_dynamodb_table.user_sessions.arn
}

output "table_stream_arn" {
  description = "The ARN of the DynamoDB table stream (if enabled)"
  value       = aws_dynamodb_table.user_sessions.stream_arn
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used to encrypt the table"
  value       = aws_kms_key.dynamodb.arn
}